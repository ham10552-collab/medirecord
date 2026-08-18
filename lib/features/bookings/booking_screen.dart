import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/app_storage.dart';
import '../../core/network/patient_client.dart';
import '../../core/network/queue_status.dart';
import '../../shared/models/booking.dart';
import '../../shared/models/patient.dart';
import '../../shared/widgets/app_drawer.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/luxury_figures.dart';
import '../../shared/widgets/skeleton.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Booking> _allBookings = [];
  List<Booking> _upcoming = [];
  List<Patient> _patients = [];
  bool _loading = true;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bookings = await DatabaseHelper().getAllBookings();
    final patients = await DatabaseHelper().getAllPatients();
    if (!mounted) return;
    final today = DateTime.now();
    final todayKey = '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    int timeMin(String t) {
      final p = t.split(' ');
      if (p.length != 2) return 0;
      final hm = p[0].split(':');
      var h = int.tryParse(hm[0]) ?? 0;
      final m = int.tryParse(hm[1]) ?? 0;
      final pm = p[1].toUpperCase() == 'PM';
      if (pm && h != 12) h += 12;
      if (!pm && h == 12) h = 0;
      return h * 60 + m;
    }

    final upcoming = bookings
        .where((b) =>
            b.status != 'completed' &&
            b.status != 'cancelled' &&
            b.date.compareTo(todayKey) >= 0)
        .toList()
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : timeMin(a.time) - timeMin(b.time);
      });
    setState(() {
      _allBookings = bookings;
      _patients = patients;
      _upcoming = upcoming;
      _loading = false;
    });
  }

  List<Booking> _bookingsForDate(DateTime date) {
    final key = _fmtDate(date);
    return _allBookings.where((b) => b.date == key).toList();
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _addBooking({Patient? patient}) async {
    final nameCtrl = TextEditingController(text: patient?.fullName ?? '');
    final phoneCtrl = TextEditingController(text: patient?.phone ?? '');
    final timeCtrl = TextEditingController(text: '10:00 AM');
    final reasonCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String? selectedTime;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              MedicalCrossFigure(size: 16),
              SizedBox(width: 10),
              Text('New Booking'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (patient == null) ...[
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Patient Name'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined)),
                  ),
                  const SizedBox(height: 8),
                ] else
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(patient.fullName),
                    subtitle: Text('${patient.age} yrs | ${patient.gender}'),
                  ),
                const SizedBox(height: 8),
                if (patient != null)
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined)),
                  ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedTime ?? '10:00 AM',
                  decoration: const InputDecoration(labelText: 'Time', prefixIcon: Icon(Icons.schedule)),
                  items: _timeSlots.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setDialogState(() => selectedTime = v),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(labelText: 'Reason (optional)', prefixIcon: Icon(Icons.notes)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes (optional)', prefixIcon: Icon(Icons.edit_note)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Date: ${_fmtDate(_selectedDate)}',
                  style: AppTheme.displayStyle(size: 14, color: AppTheme.navy),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.goldColor,
                foregroundColor: AppTheme.navyDeep,
              ),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Book'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final booking = Booking(
      id: const Uuid().v4(),
      patientId: patient?.id ?? '',
      patientName: nameCtrl.text.trim(),
      date: _fmtDate(_selectedDate),
      time: selectedTime ?? timeCtrl.text.trim(),
      reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
      status: 'pending',
      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );
    await DatabaseHelper().insertBooking(booking);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking added'), backgroundColor: AppTheme.successColor, behavior: SnackBarBehavior.floating),
      );
    }
  }

  static const _timeSlots = [
    '08:00 AM', '08:30 AM', '09:00 AM', '09:30 AM', '10:00 AM', '10:30 AM',
    '11:00 AM', '11:30 AM', '12:00 PM', '12:30 PM', '01:00 PM', '01:30 PM',
    '02:00 PM', '02:30 PM', '03:00 PM', '03:30 PM', '04:00 PM', '04:30 PM',
    '05:00 PM', '05:30 PM', '06:00 PM', '06:30 PM', '07:00 PM', '07:30 PM',
    '08:00 PM',
  ];

  int _timeMinutes(String t) {
    final parts = t.split(' ');
    if (parts.length != 2) return 0;
    final hm = parts[0].split(':');
    var h = int.tryParse(hm[0]) ?? 0;
    final m = int.tryParse(hm[1]) ?? 0;
    final isPM = parts[1].toUpperCase() == 'PM';
    if (isPM && h != 12) h += 12;
    if (!isPM && h == 12) h = 0;
    return h * 60 + m;
  }

  Future<void> _addBookingPatient(Booking b) async {
    final parts = b.patientName.trim().split(RegExp(r'\s+'));
    final nameCtrl = TextEditingController(text: parts.isNotEmpty ? parts.first : '');
    final lastNameCtrl = TextEditingController(text: parts.length > 1 ? parts.sublist(1).join(' ') : '');
    final phoneCtrl = TextEditingController(text: b.phone ?? '');
    final ageCtrl = TextEditingController();
    String gender = 'Male';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              MedicalCrossFigure(size: 16),
              SizedBox(width: 10),
              Text('Add as New Patient'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'The patient has arrived - filling in the full record moves this booking into the patients list and removes it from bookings.',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                            labelText: 'First Name', prefixIcon: Icon(Icons.person_outline)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: lastNameCtrl,
                        decoration: const InputDecoration(labelText: 'Last Name'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                            labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: ageCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Age', prefixIcon: Icon(Icons.cake_outlined)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Male'),
                      selected: gender == 'Male',
                      onSelected: (_) => setDialogState(() => gender = 'Male'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Female'),
                      selected: gender == 'Female',
                      onSelected: (_) => setDialogState(() => gender = 'Female'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.goldColor,
                foregroundColor: AppTheme.navyDeep,
              ),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Add Patient'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    final patient = Patient(
      id: const Uuid().v4(),
      firstName: nameCtrl.text.trim().isEmpty ? 'Unknown' : nameCtrl.text.trim(),
      lastName: lastNameCtrl.text.trim(),
      age: int.tryParse(ageCtrl.text) ?? 0,
      gender: gender,
      phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
      address: null,
      bloodGroup: null,
      emergencyContactName: null,
      emergencyContactPhone: null,
      photoUrl: null,
      createdBy: 'booking',
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );
    final inserted = await DatabaseHelper().insertPatient(patient);
    if (inserted == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trial limit reached (70 patients). Activate a license to continue.'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    // Also send the patient to the doctor, so he lands in the doctor's
    // waiting room / patient queue right away.
    var sentToDoctor = false;
    final ip = (await AppStorage.read('doctor_ip'))?.trim() ?? '';
    if (ip.isNotEmpty) {
      final port =
          int.tryParse((await AppStorage.read('doctor_port'))?.trim() ?? '') ?? 9876;
      final data = patient.toMap();
      data['visit_type'] = 'first_visit';
      final result = await PatientClient.sendPatient(data, ip, port);
      sentToDoctor = result['status'] == 'ok';
      if (sentToDoctor) {
        await QueueStatus.addSecretaryEntry(patient.id, patient.fullName);
      }
    }
    await DatabaseHelper().deleteBooking(b.id);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(sentToDoctor
            ? '${patient.fullName} added and sent to the doctor - now in the waiting room'
            : '${patient.fullName} added as a patient (no doctor connection - not sent)'),
        backgroundColor: sentToDoctor ? AppTheme.successColor : AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _changeStatus(Booking booking, String status) async {
    await DatabaseHelper().updateBooking(booking.copyWith(status: status));
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${booking.patientName} marked as ${_statusLabel(status)}'),
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _deleteBooking(Booking booking) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete booking?'),
        content: Text('${booking.patientName} at ${booking.time}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await DatabaseHelper().deleteBooking(booking.id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Booking deleted'),
          behavior: SnackBarBehavior.floating,
        ));
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'confirmed':
        return 'Confirmed';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Pending';
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'confirmed':
        return const Color(0xFF1976D2);
      case 'completed':
        return AppTheme.successColor;
      case 'cancelled':
        return Colors.red;
      default:
        return const Color(0xFFF57C00);
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'confirmed':
        return Icons.event_available;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.schedule;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Today',
            onPressed: () => setState(() => _selectedDate = DateTime.now()),
          ),
        ],
      ),
      drawer: AppShell.usesFixedNav(context) ? null : const AppDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addBooking(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const SkeletonPulse(child: SkeletonList())
          : Column(
              children: [
                _buildSummaryHeader(),
                _buildDaySelector(),
                _buildUpcomingPanel(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search by patient, phone or reason…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppTheme.goldLight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppTheme.goldLight.withValues(alpha: 0.5)),
                      ),
                    ),
                  ),
                ),
                Expanded(child: _buildBookingsList()),
              ],
            ),
    );
  }

  DateTime _parseDate(String d) {
    final parts = d.split('-');
    if (parts.length == 3) {
      return DateTime(
        int.tryParse(parts[0]) ?? DateTime.now().year,
        int.tryParse(parts[1]) ?? 1,
        int.tryParse(parts[2]) ?? 1,
      );
    }
    return DateTime.now();
  }

  Widget _buildUpcomingPanel() {
    if (_upcoming.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.goldColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_month, size: 16, color: AppTheme.goldDeep),
              SizedBox(width: 6),
              Expanded(
                child: Text('Upcoming Appointments',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.navy)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final b in _upcoming.take(5))
            InkWell(
              onTap: () => setState(() => _selectedDate = _parseDate(b.date)),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.goldColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.goldColor.withValues(alpha: 0.45)),
                      ),
                      child: Text(
                        b.time,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.goldDeep),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.patientName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          Text(
                            [
                              if (b.date.length >= 10)
                                '${b.date.substring(8, 10)}/${b.date.substring(5, 7)}/${b.date.substring(0, 4)}',
                              if ((b.reason ?? '').trim().isNotEmpty) b.reason!,
                            ].join('  •  '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader() {
    final today = _bookingsForDate(_selectedDate);
    final pending = _allBookings.where((b) => b.status == 'pending').length;
    final confirmed = _allBookings.where((b) => b.status == 'confirmed').length;
    final completed = _allBookings.where((b) => b.status == 'completed').length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.goldLight.withValues(alpha: 0.55), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navyDeep.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -16,
            top: -18,
            child: Icon(Icons.auto_awesome, size: 64, color: AppTheme.goldColor.withValues(alpha: 0.22)),
          ),
          Positioned(
            left: 6,
            top: 6,
            child: Transform.flip(flipY: true, child: CornerOrnament(size: 22, color: Colors.white.withValues(alpha: 0.5))),
          ),
          Positioned(
            right: 6,
            bottom: 6,
            child: CornerOrnament(size: 22, color: Colors.white.withValues(alpha: 0.5)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SparkleFigure(size: 12),
                  const SizedBox(width: 6),
                  Text(
                    'APPOINTMENTS',
                    style: TextStyle(
                      color: AppTheme.goldLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const MedicalCrossFigure(size: 18),
                  const SizedBox(width: 10),
                  Text(
                    '${today.length} booking${today.length == 1 ? '' : 's'} today',
                    style: AppTheme.displayStyle(size: 20, color: Colors.white, gold: true),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _summaryChip(Icons.schedule, '$pending', 'Pending', const Color(0xFFFFB74D)),
                  const SizedBox(width: 8),
                  _summaryChip(Icons.event_available, '$confirmed', 'Confirmed', const Color(0xFF64B5F6)),
                  const SizedBox(width: 8),
                  _summaryChip(Icons.check_circle, '$completed', 'Completed', const Color(0xFF69F0AE)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySelector() {
    final days = List.generate(60, (i) => DateTime.now().add(Duration(days: i)));
    return SizedBox(
      height: 82,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: days.length,
        itemBuilder: (context, i) {
          final d = days[i];
          final isSelected = _fmtDate(d) == _fmtDate(_selectedDate);
          final hasBookings = _bookingsForDate(d).isNotEmpty;
          final isToday = _fmtDate(d) == _fmtDate(DateTime.now());
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _selectedDate = d),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 62,
                decoration: BoxDecoration(
                  gradient: isSelected ? AppTheme.goldGradient : null,
                  color: isSelected ? null : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppTheme.goldDeep : hasBookings ? AppTheme.goldColor.withValues(alpha: 0.6) : AppTheme.dividerColor,
                    width: 1.2,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: AppTheme.goldColor.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))]
                      : [BoxShadow(color: AppTheme.navy.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isToday ? 'TODAY' : _weekdayName(d.weekday).toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: isSelected ? AppTheme.navyDeep : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${d.day}',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? AppTheme.navyDeep : AppTheme.navy,
                      ),
                    ),
                    if (hasBookings)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(top: 3),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.navyDeep : AppTheme.goldDeep,
                          shape: BoxShape.circle,
                        ),
                      )
                    else
                      const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            );
          },
        ),
    );
  }

  Widget _buildBookingsList() {
    final dayBookings = _bookingsForDate(_selectedDate)
      ..sort((a, b) => _timeMinutes(a.time) - _timeMinutes(b.time));
    final visible = _searchQuery.isEmpty
        ? dayBookings
        : dayBookings.where((b) =>
            b.patientName.toLowerCase().contains(_searchQuery) ||
            (b.phone ?? '').toLowerCase().contains(_searchQuery) ||
            (b.reason ?? '').toLowerCase().contains(_searchQuery)).toList();
    if (visible.isEmpty) {
      return EmptyState(
        icon: Icons.event_available_outlined,
        title: _searchQuery.isNotEmpty ? 'No matches for "$_searchQuery"' : 'No appointments on this day',
        message: _searchQuery.isNotEmpty
            ? 'Try a different name, phone number or reason.'
            : 'Tap + to schedule a patient visit for ${_fmtDate(_selectedDate)}.',
        actionLabel: _searchQuery.isNotEmpty ? 'Clear search' : 'Add Booking',
        onAction: _searchQuery.isNotEmpty
            ? () {
                _searchCtrl.clear();
                setState(() => _searchQuery = '');
              }
            : _addBooking,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
      itemCount: dayBookings.length,
      itemBuilder: (context, i) {
        final b = dayBookings[i];
        final patient = _patients.firstWhere((p) => p.id == b.patientId, orElse: () => Patient(
          id: '',
          firstName: b.patientName,
          lastName: '',
          age: 0,
          gender: '',
          createdBy: '',
          createdAt: '',
          updatedAt: '',
        ));
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _statusColor(b.status).withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(color: AppTheme.navy.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: patient.id.isNotEmpty ? () => context.push('/patients/${patient.id}') : null,
              borderRadius: BorderRadius.circular(16),
              child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 70,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppTheme.primaryColor.withValues(alpha: 0.12), AppTheme.primaryColor.withValues(alpha: 0.04)],
                    ),
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_statusIcon(b.status), size: 18, color: _statusColor(b.status)),
                      const SizedBox(height: 4),
                      Text(
                        b.time,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryColor,
                          fontFamily: AppTheme.displayFont,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                b.patientName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.navy,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _statusColor(b.status).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_statusIcon(b.status), size: 12, color: _statusColor(b.status)),
                                  const SizedBox(width: 4),
                                  Text(
                                    _statusLabel(b.status),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: _statusColor(b.status),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (b.reason != null && b.reason!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            b.reason!,
                            style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.phone_outlined, size: 13, color: AppTheme.primaryColor),
                            const SizedBox(width: 4),
                            Text(
                              b.phone ?? patient.phone ?? 'No phone',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(width: 14),
                            if (patient.id.isNotEmpty)
                              Text(
                                '${patient.age} yrs • ${patient.gender}',
                                style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                              ),
                          ],
                        ),
                        if (b.status != 'completed') ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (b.patientId.trim().isEmpty) ...[
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _addBookingPatient(b),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.navyDeep,
                                      minimumSize: const Size(0, 36),
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      side: const BorderSide(color: AppTheme.goldDeep),
                                    ),
                                    icon: const Icon(Icons.person_add_alt, size: 15),
                                    label: const Text('Add as Patient', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _changeStatus(b, 'confirmed'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF1976D2),
                                    minimumSize: const Size(0, 36),
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    side: const BorderSide(color: Color(0xFF1976D2)),
                                  ),
                                  icon: const Icon(Icons.event_available, size: 15),
                                  label: const Text('Confirm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _changeStatus(b, 'completed'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.successColor,
                                    minimumSize: const Size(0, 36),
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                  ),
                                  icon: const Icon(Icons.done_all, size: 15),
                                  label: const Text('Done', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Actions',
                  onSelected: (v) {
                    if (v == 'delete') {
                      _deleteBooking(b);
                    } else {
                      _changeStatus(b, v);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'pending', child: Text('Mark Pending')),
                    const PopupMenuItem(value: 'confirmed', child: Text('Mark Confirmed')),
                    const PopupMenuItem(value: 'completed', child: Text('Mark Completed')),
                    const PopupMenuItem(value: 'cancelled', child: Text('Mark Cancelled')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _weekdayName(int w) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][w - 1];
}
