import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/database/database_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/patient.dart';
import '../../shared/models/booking.dart';

/// Clinova-style global search (Ctrl+K): finds patients and bookings from
/// any screen and opens them directly.
Future<void> showGlobalSearch(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _GlobalSearchDialog(),
  );
}

class _GlobalSearchDialog extends StatefulWidget {
  const _GlobalSearchDialog();

  @override
  State<_GlobalSearchDialog> createState() => _GlobalSearchDialogState();
}

class _GlobalSearchDialogState extends State<_GlobalSearchDialog> {
  final TextEditingController _ctrl = TextEditingController();
  String _query = '';
  List<Patient> _patients = const [];
  List<Booking> _bookings = const [];
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper();
    final results = await Future.wait([
      db.getAllPatients(),
      db.getAllBookings(),
    ]);
    if (!mounted) return;
    setState(() {
      _patients = results[0] as List<Patient>;
      _bookings = results[1] as List<Booking>;
      _ready = true;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _openPatient(Patient p) {
    Navigator.pop(context);
    context.push('/patients/${p.id}');
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final patients = q.isEmpty
        ? _patients.take(6).toList()
        : _patients
            .where((p) =>
                p.fullName.toLowerCase().contains(q) ||
                (p.phone ?? '').toLowerCase().contains(q))
            .take(8)
            .toList();
    final bookings = q.isEmpty
        ? _bookings.take(6).toList()
        : _bookings
            .where((b) =>
                b.patientName.toLowerCase().contains(q) ||
                (b.reason ?? '').toLowerCase().contains(q))
            .take(8)
            .toList();
    final hasResults = patients.isNotEmpty || bookings.isNotEmpty;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 120, vertical: 90),
      child: Container(
        width: 720,
        height: 520,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 10),
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppTheme.goldDeep, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: const InputDecoration(
                        hintText: 'Search anything…  (Esc to close)',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.goldLight),
            Expanded(
              child: !_ready
                  ? const Center(child: CircularProgressIndicator())
                  : !hasResults
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search_off,
                                  size: 44, color: AppTheme.textSecondary),
                              const SizedBox(height: 10),
                              Text(
                                q.isEmpty
                                    ? 'Start typing to search'
                                    : 'No results for "$q"',
                                style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13.5),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          children: [
                            if (patients.isNotEmpty) ...[
                              _header('Patients', Icons.people_outline),
                              for (final p in patients)
                                _patientTile(p, q),
                            ],
                            if (bookings.isNotEmpty) ...[
                              _header('Bookings', Icons.calendar_month_outlined),
                              for (final b in bookings) _bookingTile(b, q),
                            ],
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.goldDeep),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _patientTile(Patient p, String q) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
        child: Text(
          p.fullName.substring(0, 1).toUpperCase(),
          style: const TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 12),
        ),
      ),
      title: Text(
        p.fullName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [p.phone ?? '', p.age > 0 ? '${p.age} years' : '']
            .where((s) => s.isNotEmpty)
            .join(' · '),
        style: const TextStyle(fontSize: 11.5),
      ),
      trailing: const Icon(Icons.chevron_right, size: 16, color: AppTheme.textSecondary),
      onTap: () => _openPatient(p),
    );
  }

  Widget _bookingTile(Booking b, String q) {
    return ListTile(
      dense: true,
      leading: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: AppTheme.goldColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.schedule, size: 16, color: AppTheme.goldDeep),
      ),
      title: Text(
        '${b.patientName} — ${b.time}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${b.date}${(b.reason ?? '').trim().isEmpty ? '' : ' · ${b.reason}'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11.5),
      ),
      trailing: const Icon(Icons.chevron_right, size: 16, color: AppTheme.textSecondary),
      onTap: () {
        Navigator.pop(context);
        context.push('/bookings');
      },
    );
  }
}