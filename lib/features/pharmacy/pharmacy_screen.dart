import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/database/database_provider.dart';
import '../../core/database/database_helper.dart';
import '../../core/network/patient_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_storage.dart';
import '../../shared/models/prescription.dart';
import '../../shared/widgets/app_drawer.dart';
import '../../shared/widgets/luxury_figures.dart';
import '../prescriptions/prescription_printer.dart';

class PharmacyScreen extends ConsumerStatefulWidget {
  const PharmacyScreen({super.key});

  @override
  ConsumerState<PharmacyScreen> createState() => _PharmacyScreenState();
}

class _PharmacyScreenState extends ConsumerState<PharmacyScreen> {
  String _filter = 'pending';
  String _query = '';
  String _dateFilter = '';
  bool _todayOnly = false;
  String? _syncStatus;
  String? _syncError;
  bool _syncing = false;
  Timer? _pollTimer;
  int _lastSeenCount = -1;
  List<Map<String, String>> _doctors = [];
  String _view = 'queue';
  List<Map<String, dynamic>> _stock = [];
  String _stockQuery = '';
  int _lowStock = 0;

  static const int _lowThreshold = 3;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadStock();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final rawList = await AppStorage.readList('doctor_pcs');
    if (rawList.isNotEmpty) {
      final parsed = rawList.map((e) {
        try {
          return (json.decode(e) as Map).cast<String, String>();
        } catch (_) {
          return <String, String>{};
        }
      }).where((m) => (m['ip'] ?? '').trim().isNotEmpty).toList();
      if (mounted) setState(() => _doctors = parsed);
      return;
    }
    // Legacy single-doctor config migrates into the list.
    final ip = await AppStorage.read('doctor_ip') ?? '';
    if (ip.trim().isNotEmpty) {
      final port = int.tryParse(await AppStorage.read('doctor_port') ?? '') ?? 9876;
      final migrated = [
        {'name': 'Doctor PC', 'ip': ip.trim(), 'port': '$port'},
      ];
      await _saveDoctors(migrated);
      if (mounted) setState(() => _doctors = migrated);
    }
  }

  Future<void> _saveDoctors(List<Map<String, String>> doctors) async {
    await AppStorage.writeList('doctor_pcs',
        doctors.map((d) => json.encode(d)).toList());
  }

  /// Live check: the background sync service already pulls from every doctor
  /// PC every 3 seconds - here we only refresh the list and notify when new
  /// prescriptions arrived.
  Future<void> _poll() async {
    if (_syncing) return;
    ref.invalidate(pharmacyQueueProvider);
    final fresh = await ref.read(pharmacyQueueProvider.future);
    final total = fresh.length;
    final grew = total > _lastSeenCount && _lastSeenCount >= 0;
    _lastSeenCount = total;
    if (grew && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('New prescription received at the pharmacy'),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _manageDoctors() async {
    final working = _doctors
        .map((d) => {
              'name': d['name'] ?? '',
              'ip': d['ip'] ?? '',
              'port': d['port'] ?? '9876',
            })
        .toList();
    final ctrls = <List<TextEditingController>>[
      for (final d in working)
        [
          TextEditingController(text: d['name']),
          TextEditingController(text: d['ip']),
          TextEditingController(text: d['port']),
        ],
    ];
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Doctor PCs to Sync'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Add every doctor computer in the clinic. The pharmacy syncs '
                    'prescriptions from all of them.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < ctrls.length; i++) ...[
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: ctrls[i][0],
                            decoration: const InputDecoration(labelText: 'Name', hintText: 'Dr. Ahmed', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 4,
                          child: TextField(
                            controller: ctrls[i][1],
                            decoration: const InputDecoration(labelText: 'IP', hintText: '192.168.1.10', prefixIcon: Icon(Icons.lan, size: 16), isDense: true),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: ctrls[i][2],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Port', prefixIcon: Icon(Icons.numbers, size: 16), isDense: true),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          onPressed: () {
                            setDlg(() {
                              ctrls.removeAt(i);
                              working.removeAt(i);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  TextButton.icon(
                    onPressed: () {
                      setDlg(() {
                        ctrls.add([
                          TextEditingController(text: 'Doctor PC ${ctrls.length + 1}'),
                          TextEditingController(),
                          TextEditingController(text: '9876'),
                        ]);
                        working.add({'name': '', 'ip': '', 'port': '9876'});
                      });
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add doctor PC'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final list = <Map<String, String>>[];
                for (var i = 0; i < ctrls.length; i++) {
                  final ip = ctrls[i][1].text.trim();
                  if (ip.isEmpty) continue;
                  list.add({
                    'name': ctrls[i][0].text.trim().isEmpty
                        ? 'Doctor PC ${i + 1}'
                        : ctrls[i][0].text.trim(),
                    'ip': ip,
                    'port': ctrls[i][2].text.trim().isEmpty
                        ? '9876'
                        : ctrls[i][2].text.trim(),
                  });
                }
                await _saveDoctors(list);
                if (!ctx.mounted) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await _loadSettings();
      await _syncFromAllDoctors();
    }
  }

  Future<void> _syncFromAllDoctors() async {
    if (_doctors.isEmpty) {
      if (mounted) {
        setState(() {
          _syncStatus = null;
          _syncError = 'No doctor PC configured - add one first';
        });
      }
      return;
    }
    setState(() {
      _syncing = true;
      _syncStatus = 'Syncing from ${_doctors.length} doctor PC(s)...';
      _syncError = null;
    });
    final db = DatabaseHelper();
    final existing = await db.getPharmacyQueue();
    final existingNames = {
      for (final r in existing) r['id']: (r['pharmacist_name'] as String?) ?? '',
    };
    var total = 0;
    final errors = <String>[];
    for (final doc in _doctors) {
      final ip = doc['ip']!.trim();
      final port = int.tryParse(doc['port'] ?? '') ?? 9876;
      final (queue, err) = await PatientClient.fetchPharmacy(ip, port);
      if (err != null) {
        errors.add('${doc['name']} ($ip): $err');
        continue;
      }
      final host = '$ip:$port';
      final docLabel = (doc['name'] ?? '').trim();
      for (final rx in queue) {
        final rxMap = (rx as Map).cast<String, dynamic>();
        final items = ((rxMap['items'] as List?) ?? const [])
            .map((i) => PrescriptionItem.fromMap((i as Map).cast<String, dynamic>()))
            .toList();
        final rawDoctor = (rxMap['doctor_name'] as String? ?? '').trim();
        final pres = Prescription(
          id: rxMap['id'] as String,
          patientId: rxMap['patient_id'] as String,
          doctorName: (rawDoctor.isEmpty || rawDoctor == 'Unknown') && docLabel.isNotEmpty
              ? docLabel
              : rawDoctor,
          diagnosis: rxMap['diagnosis'] as String? ?? '',
          items: items,
          notes: rxMap['notes'] as String? ?? '',
          createdAt: rxMap['created_at'] as String,
          updatedAt: rxMap['updated_at'] as String,
          status: rxMap['status'] as String? ?? 'pending',
          dispensedBy: rxMap['dispensed_by'] as String?,
          dispensedAt: rxMap['dispensed_at'] as String?,
          pharmacistName: (rxMap['pharmacist_name'] as String?)?.isNotEmpty == true
              ? rxMap['pharmacist_name'] as String
              : existingNames[rxMap['id']],
          doctorHost: host,
          sentToPharmacy: true,
        );
        total += await db.upsertPrescription(pres);
      }
    }
    ref.invalidate(pharmacyQueueProvider);
    if (mounted) {
      setState(() {
        _syncing = false;
        _syncStatus = total == 0
            ? 'No new prescriptions from ${_doctors.length} doctor PC(s)'
            : 'Synced $total prescription(s) from ${_doctors.length} doctor PC(s)';
        _syncError = errors.isEmpty ? null : errors.first;
      });
    }
  }

  /// Pushes a dispense action back to the doctor PC the prescription came
  /// from (falls back to the sole configured PC for legacy records).
  Future<void> _pushAction(Map<String, dynamic> rx, String action) async {
    final host = (rx['doctor_host'] as String? ?? '').trim();
    String ip;
    int port;
    if (host.isNotEmpty) {
      final parts = host.split(':');
      ip = parts[0];
      port = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 9876;
    } else if (_doctors.length == 1) {
      ip = _doctors.first['ip']!.trim();
      port = int.tryParse(_doctors.first['port'] ?? '') ?? 9876;
    } else {
      return;
    }
    await PatientClient.pharmacyAction(
        rx['id'] as String, action, _pharmacistName(), ip, port);
  }

  String _pharmacistName() {
    try {
      return FirebaseAuth.instance.currentUser?.displayName?.trim().isNotEmpty == true
          ? FirebaseAuth.instance.currentUser!.displayName!.trim()
          : 'Pharmacist';
    } catch (_) {
      return 'Pharmacist';
    }
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> all) {
    final q = _query.toLowerCase().trim();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return all.where((rx) {
      final status = (rx['status'] as String?) ?? 'pending';
      // While typing, search across both tabs - the tab counts only apply
      // when there is no search query.
      if (q.isEmpty && status != _filter) return false;
      final created = (rx['created_at'] as String? ?? '');
      if (_todayOnly && !created.startsWith(today)) return false;
      if (_dateFilter.isNotEmpty && !created.startsWith(_dateFilter)) return false;
      if (q.isEmpty) return true;
      final patientName = (rx['patient_name'] as String?)?.toLowerCase() ?? '';
      final doctor = (rx['doctor_name'] as String?)?.toLowerCase() ?? '';
      final phone = (rx['patient_phone'] as String?)?.toLowerCase() ?? '';
      final id = (rx['id'] as String? ?? '').toLowerCase();
      return patientName.contains(q) ||
          doctor.contains(q) ||
          'dr. $doctor'.contains(q) ||
          phone.contains(q) ||
          created.contains(q) ||
          id.contains(q);
    }).toList();
  }

  Future<void> _loadStock() async {
    final stock = await DatabaseHelper().getInventory();
    final low = await DatabaseHelper().getLowStockCount(_lowThreshold);
    if (!mounted) return;
    setState(() {
      _stock = stock;
      _lowStock = low;
    });
  }

  /// Adjusts stock for every medicine on a prescription.
  /// [delta] is -1 per unit when dispensing, +1 when undoing.
  Future<(List<String>, List<String>)> _adjustStockForRx(Map<String, dynamic> rx, int delta) async {
    final db = DatabaseHelper();
    final matched = <String>[];
    final missing = <String>[];
    int matchedCount = 0;
    for (final item in (rx['items'] as List? ?? [])) {
      final name = ((item as Map<String, dynamic>)['medicine_name'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      if (await db.adjustInventory(name, delta) > 0) {
        if (!matched.contains(name)) matched.add(name);
        matchedCount++;
      } else if (!missing.contains(name)) {
        missing.add(name);
      }
    }
    return (matched, missing);
  }

  Future<void> _markDispensed(Map<String, dynamic> rx) async {
    final db = DatabaseHelper();
    await db.markPrescriptionPharmacist(rx['id'] as String, _pharmacistName());
    final updated = await db.updatePrescriptionStatus(
      rx['id'] as String,
      status: 'dispensed',
      dispensedBy: _pharmacistName(),
      dispensedAt: DateTime.now().toIso8601String(),
    );
    if (updated > 0) {
      await _pushAction(rx, 'dispense');
    }
    if (updated > 0) {
      final (_, missing) = await _adjustStockForRx(rx, -1);
      final low = await db.getLowStockCount(_lowThreshold);
      if (!mounted) return;
      setState(() => _lowStock = low);
      if (low > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Dispensed${missing.isEmpty ? '' : ' (${missing.join(', ')} not in stock)'}. '
              'Attention: $low item(s) low on stock!',
            ),
            backgroundColor: AppTheme.goldDeep,
            duration: const Duration(seconds: 4),
          ),
        );
      } else if (missing.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dispensed. Note: ${missing.join(', ')} not in the stock list'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
    ref.invalidate(pharmacyQueueProvider);
    await _loadStock();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      updated > 0
          ? const SnackBar(
              content: Text('Dispensed'),
              backgroundColor: AppTheme.successColor,
              duration: Duration(seconds: 2),
            )
          : const SnackBar(content: Text('Update failed - try again'), backgroundColor: AppTheme.errorColor),
    );
  }

  Future<void> _undoDispense(Map<String, dynamic> rx) async {
    final updated = await DatabaseHelper().updatePrescriptionStatus(rx['id'] as String, status: 'pending');
    if (updated > 0) {
      await _pushAction(rx, 'pending');
      await _adjustStockForRx(rx, 1);
      await _loadStock();
    }
    ref.invalidate(pharmacyQueueProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      updated > 0
          ? const SnackBar(content: Text('Moved back to pending - stock restored'), duration: Duration(seconds: 2))
          : const SnackBar(content: Text('Update failed - try again'), backgroundColor: AppTheme.errorColor),
    );
  }

  Widget _statBox(String label, int value, Color color, IconData icon,
      {VoidCallback? onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$value',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 11, color: color),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  Future<void> _printDailyReport(List<Map<String, dynamic>> all) async {
    final now = DateTime.now();
    final today = now.toIso8601String().substring(0, 10);
    final yesterday = now.subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);

    String? choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Dispensed report for...'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, today),
            child: const Text('Today'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, yesterday),
            child: const Text('Yesterday'),
          ),
          SimpleDialogOption(
            onPressed: () async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: now,
                firstDate: DateTime(now.year - 5),
                lastDate: now,
              );
              if (picked != null) {
                if (ctx.mounted) Navigator.pop(ctx, picked.toIso8601String().substring(0, 10));
              }
            },
            child: const Text('Pick a date...'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'all'),
            child: const Text('Everything (all dates)'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;

    List<Map<String, dynamic>> rows;
    String label;
    if (choice == 'all') {
      rows = all.where((r) => (r['status'] as String?) == 'dispensed').toList();
      label = 'all';
    } else {
      rows = all
          .where((r) =>
              (r['status'] as String?) == 'dispensed' &&
              ((r['dispensed_at'] as String?) ?? '').startsWith(choice))
          .toList();
      label = choice;
    }
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nothing dispensed on that day - report cannot be created'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    try {
      final path = await generatePharmacyReportPdf(rows, label);
      if (mounted) {
        if (path.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Print cancelled'), backgroundColor: AppTheme.errorColor),
          );
          return;
        }
        await printPrescriptionDirect(context, path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Report saved: $path'),
              duration: const Duration(seconds: 6),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not generate the report: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _printRx(Map<String, dynamic> rx) async {
    try {
      final db = DatabaseHelper();
      await db.markPrescriptionPharmacist(rx['id'] as String, _pharmacistName());
      final name = (rx['pharmacist_name'] as String?) ?? _pharmacistName();
      final path = await generatePharmacyPdf(rx, name);
      if (mounted) {
        if (path.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Print cancelled'), backgroundColor: AppTheme.errorColor),
          );
          return;
        }
        await printPrescriptionDirect(context, path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not generate the print copy: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _openDetail(Map<String, dynamic> rx) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const MedicalCrossFigure(size: 18),
                    const SizedBox(width: 10),
                    Text('Prescription', style: AppTheme.displayStyle(size: 19, color: AppTheme.navy)),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Print pharmacy copy',
                      icon: const Icon(Icons.print, color: AppTheme.goldDeep),
                      onPressed: () {
                        _printRx(rx);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const GoldDivider(),
                const SizedBox(height: 12),
                Text('Patient: ${rx['patient_name'] ?? 'Unknown'}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text('Doctor: ${rx['doctor_name'] ?? '-'}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                if ((rx['pharmacist_name'] as String?)?.isNotEmpty ?? false)
                  Text('Pharmacist: ${rx['pharmacist_name']}', style: const TextStyle(fontSize: 13, color: AppTheme.goldDeep, fontWeight: FontWeight.w600)),
                Text('Date: ${(rx['created_at'] as String? ?? '').substring(0, 10)}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                if ((rx['diagnosis'] as String?)?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 8),
                  Text('Diagnosis: ${rx['diagnosis']}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 12),
                const Text('Medicines', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView.separated(
                    itemCount: (rx['items'] as List?)?.length ?? 0,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final item = (rx['items'] as List)[i] as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.medication, size: 16, color: AppTheme.primaryColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['medicine_name'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                                  Text(
                                    [item['dosage'], item['frequency'], item['duration']]
                                        .where((s) => (s as String? ?? '').trim().isNotEmpty)
                                        .join(' | '),
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                  if ((item['instructions'] as String? ?? '').trim().isNotEmpty)
                                    Text('Note: ${item['instructions']}', style: const TextStyle(fontSize: 12, color: AppTheme.goldDeep)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if ((rx['notes'] as String?)?.isNotEmpty ?? false) ...[
                  const Divider(),
                  Text('Doctor notes: ${rx['notes']}', style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic)),
                ],
                if (rx['status'] == 'dispensed') ...[
                  const Divider(),
                  Text(
                    'Dispensed by ${rx['dispensed_by'] ?? '-'} on ${(rx['dispensed_at'] as String? ?? '').substring(0, 10)}',
                    style: const TextStyle(fontSize: 12.5, color: AppTheme.successColor, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Spacer(),
                    if (rx['status'] == 'pending') ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _markDispensed(rx);
                          },
                          icon: const Icon(Icons.inventory_2, size: 18),
                          label: const Text('Mark as Dispensed'),
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _undoDispense(rx);
                          },
                          icon: const Icon(Icons.replay, size: 18),
                          label: const Text('Back to Pending'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final queueAsync = ref.watch(pharmacyQueueProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmacy'),
        actions: [
          Badge(
            isLabelVisible: _lowStock > 0,
            label: Text('$_lowStock'),
            backgroundColor: AppTheme.errorColor,
            child: IconButton(
              tooltip: 'Stock level (low stock: $_lowStock)',
              icon: const Icon(Icons.inventory_2_outlined),
              onPressed: () {
                setState(() {
                  _view = _view == 'stock' ? 'queue' : 'stock';
                  if (_view == 'stock') _loadStock();
                });
              },
            ),
          ),
          IconButton(
            tooltip: 'Print today\'s dispensed report',
            icon: const Icon(Icons.receipt_long),
            onPressed: () async {
              final all = ref.read(pharmacyQueueProvider).valueOrNull ?? [];
              await _printDailyReport(all);
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'Search patient, doctor, phone or date...',
                      prefixIcon: Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Pick a date',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    _dateFilter.isEmpty ? Icons.calendar_month : Icons.calendar_month_outlined,
                    color: _dateFilter.isNotEmpty ? AppTheme.goldDeep : null,
                  ),
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: now,
                      firstDate: DateTime(now.year - 3),
                      lastDate: now,
                    );
                    if (picked != null) {
                      setState(() => _dateFilter = picked.toIso8601String().substring(0, 10));
                    }
                  },
                ),
                if (_dateFilter.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear date',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _dateFilter = ''),
                  ),
              ],
            ),
          ),
        ),
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          _syncBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'queue',
                        label: Text('Prescriptions${_lowStock > 0 ? ' ' : ''}'),
                        icon: const Icon(Icons.receipt_long, size: 16),
                      ),
                      ButtonSegment(
                        value: 'stock',
                        label: Text(_lowStock > 0 ? 'Stock ($_lowStock low)' : 'Stock'),
                        icon: const Icon(Icons.inventory_2, size: 16),
                      ),
                    ],
                    selected: {_view},
                    onSelectionChanged: (s) {
                      setState(() => _view = s.first);
                      if (s.first == 'stock') _loadStock();
                    },
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: queueAsync.when(
              data: (all) {
                if (_view == 'stock') {
                  return _buildStockPanel();
                }
                final items = _filtered(all);
                final pending = all.where((r) => (r['status'] as String?) == 'pending').length;
                final dispensed = all.length - pending;
                final today = DateTime.now().toIso8601String().substring(0, 10);
                final dispensedToday = all
                    .where((r) =>
                        (r['status'] as String?) == 'dispensed' &&
                        ((r['dispensed_at'] as String?) ?? '').startsWith(today))
                    .length;
                final totalToday = all
                    .where((r) => ((r['created_at'] as String?) ?? '').startsWith(today))
                    .length;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                      child: Row(
                        children: [
                          _statBox('Pending', pending, AppTheme.goldDeep, Icons.schedule,
                              onTap: () => setState(() => _filter = 'pending')),
                          const SizedBox(width: 8),
                          _statBox('Dispensed', dispensed, AppTheme.successColor, Icons.check_circle,
                              onTap: () => setState(() => _filter = 'dispensed')),
                          const SizedBox(width: 8),
                          _statBox('Dispensed today', dispensedToday, AppTheme.primaryColor, Icons.today,
                              onTap: () => setState(() {
                                _todayOnly = true;
                                _filter = 'dispensed';
                              })),
                          const SizedBox(width: 8),
                          _statBox('Total today', totalToday, AppTheme.navy, Icons.medication,
                              onTap: () => setState(() {
                                _todayOnly = true;
                                _filter = 'pending';
                              })),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                      child: Row(
                        children: [
                          FilterChip(
                            label: const Text('Today'),
                            selected: _todayOnly,
                            visualDensity: VisualDensity.compact,
                            onSelected: (v) => setState(() => _todayOnly = v),
                          ),
                          if (_dateFilter.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: Text(
                                'Date: $_dateFilter',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.goldDeep,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'pending',
                      label: Text('Pending ($pending)'),
                      icon: const Icon(Icons.schedule, size: 16),
                    ),
                    ButtonSegment(
                      value: 'dispensed',
                      label: Text('Dispensed ($dispensed)'),
                      icon: const Icon(Icons.check_circle, size: 16),
                    ),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (s) => setState(() => _filter = s.first),
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                ),
              ),
              const SizedBox(height: 4),
              if (items.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_pharmacy_outlined, size: 52, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                        const SizedBox(height: 10),
                        Text(
                          _filter == 'pending' ? 'No pending prescriptions' : 'No dispensed prescriptions yet',
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final rx = items[i];
                      final isDispensed = rx['status'] == 'dispensed';
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: (isDispensed
                                    ? AppTheme.successColor
                                    : AppTheme.goldColor)
                                .withValues(alpha: 0.16),
                            child: Icon(
                              isDispensed ? Icons.check_circle : Icons.medication,
                              color: isDispensed ? AppTheme.successColor : AppTheme.goldDeep,
                              size: 20,
                            ),
                          ),
                          title: Text(rx['patient_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dr. ${rx['doctor_name'] ?? '-'} • ${(rx['created_at'] as String? ?? '').substring(0, 10)} • ${(rx['items'] as List?)?.length ?? 0} item(s)',
                                style: const TextStyle(fontSize: 12),
                              ),
                              if ((rx['patient_phone'] as String? ?? '').trim().isNotEmpty)
                                Text(
                                  'Phone: ${rx['patient_phone']}',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.goldDeep),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Print pharmacy copy',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _printRx(rx),
                                icon: const Icon(Icons.print, size: 19, color: AppTheme.goldDeep),
                              ),
                              if (isDispensed)
                                const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Text('Dispensed', style: TextStyle(fontSize: 12, color: AppTheme.successColor, fontWeight: FontWeight.w700)),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.goldColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text('PENDING', style: TextStyle(fontSize: 11, color: AppTheme.goldDeep, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                                ),
                            ],
                          ),
                          onTap: () => _openDetail(rx),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
        error: (_, __) => const Center(child: Text('Error loading prescriptions')),
        loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
      floatingActionButton: _view == 'stock'
          ? FloatingActionButton.extended(
              onPressed: () => _editStockItem(null),
              icon: const Icon(Icons.add),
              label: const Text('Add Medicine'),
            )
          : _filter == 'pending'
          ? FloatingActionButton.extended(
              onPressed: () async {
                final pending = (ref.read(pharmacyQueueProvider).valueOrNull ?? [])
                    .where((r) => (r['status'] as String?) == 'pending')
                    .toList();
                if (pending.isEmpty) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No pending prescriptions')));
                  return;
                }
                for (final rx in pending) {
                  await DatabaseHelper().updatePrescriptionStatus(
                    rx['id'] as String,
                    status: 'dispensed',
                    dispensedBy: _pharmacistName(),
                    dispensedAt: DateTime.now().toIso8601String(),
                  );
                  await _pushAction(rx, 'dispense');
                  await _adjustStockForRx(rx, -1);
                }
                ref.invalidate(pharmacyQueueProvider);
                await _loadStock();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Dispensed ${pending.length} prescription(s)'), backgroundColor: AppTheme.successColor),
                  );
                }
              },
              icon: const Icon(Icons.done_all),
              label: const Text('Dispense All'),
            )
          : null,
    );
  }

  Widget _buildStockPanel() {
    final q = _stockQuery.trim().toLowerCase();
    final items = q.isEmpty
        ? _stock
        : _stock.where((m) =>
            (m['medicine_name'] as String? ?? '').toLowerCase().contains(q) ||
            (m['form'] as String? ?? '').toLowerCase().contains(q) ||
            (m['batch'] as String? ?? '').toLowerCase().contains(q)).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _view = 'queue'),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back to prescriptions'),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _stockQuery = v),
                  decoration: const InputDecoration(
                    hintText: 'Search stock by name, form or batch...',
                    prefixIcon: Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Stock drops automatically with every dispense and is restored when you undo. Low stock = $_lowThreshold or fewer.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 52, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                      const SizedBox(height: 10),
                      Text(
                        q.isEmpty
                            ? 'No stock yet - add your first medicine'
                            : 'No stock matches your search',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      if (q.isEmpty)
                        ElevatedButton.icon(
                          onPressed: () => _editStockItem(null),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Medicine'),
                        ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final item = items[i];
                    final qty = (item['quantity'] as num?)?.toInt() ?? 0;
                    final low = qty <= _lowThreshold;
                    final name = item['medicine_name'] as String? ?? '';
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: (low ? AppTheme.errorColor : AppTheme.successColor).withValues(alpha: 0.16),
                          child: Icon(
                            Icons.medication,
                            color: low ? AppTheme.errorColor : AppTheme.successColor,
                            size: 20,
                          ),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              [
                                (item['form'] as String? ?? '').trim(),
                                (item['batch'] as String? ?? '').trim(),
                                (item['expiry'] as String? ?? '').trim(),
                              ].where((s) => s.isNotEmpty).join('  •  '),
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (low)
                              const Text(
                                'Low stock - reorder',
                                style: TextStyle(fontSize: 11.5, color: AppTheme.errorColor, fontWeight: FontWeight.w700),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Restock +1',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.add_circle_outline, size: 20, color: AppTheme.successColor),
                              onPressed: () async {
                                await DatabaseHelper().adjustInventory(name, 1);
                                await _loadStock();
                              },
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: (low ? AppTheme.errorColor : AppTheme.goldColor).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Qty: $qty',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: low ? AppTheme.errorColor : AppTheme.goldDeep,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Minus 1',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.remove_circle_outline, size: 20),
                              onPressed: qty <= 0 ? null : () async {
                                await DatabaseHelper().adjustInventory(name, -1);
                                await _loadStock();
                              },
                            ),
                            IconButton(
                              tooltip: 'Edit',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _editStockItem(item),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.errorColor),
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete from stock?'),
                                    content: Text('Remove "$name" from the stock list?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  await DatabaseHelper().deleteInventoryItem(item['id'] as String);
                                  await _loadStock();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _editStockItem(Map<String, dynamic>? existing) async {
    final nameCtrl = TextEditingController(text: existing?['medicine_name'] as String? ?? '');
    final formCtrl = TextEditingController(text: existing?['form'] as String? ?? '');
    final batchCtrl = TextEditingController(text: existing?['batch'] as String? ?? '');
    final expiryCtrl = TextEditingController(text: existing?['expiry'] as String? ?? '');
    int qty = (existing?['quantity'] as num?)?.toInt() ?? 0;
    int qtyHolder = qty;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(existing == null ? 'Add Medicine to Stock' : 'Edit Stock Item'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    autofocus: existing == null,
                    decoration: const InputDecoration(labelText: 'Medicine name *'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: formCtrl,
                          decoration: const InputDecoration(labelText: 'Form (tab/syrup...)'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: batchCtrl,
                          decoration: const InputDecoration(labelText: 'Batch no.'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: expiryCtrl,
                          decoration: const InputDecoration(labelText: 'Expiry (YYYY-MM-DD)'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(text: '$qtyHolder'),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Quantity *'),
                          onChanged: (v) => qtyHolder = int.tryParse(v.trim()) ?? 0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                await DatabaseHelper().upsertInventoryItem({
                  'id': existing?['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
                  'medicine_name': name,
                  'form': formCtrl.text.trim(),
                  'batch': batchCtrl.text.trim(),
                  'expiry': expiryCtrl.text.trim(),
                  'quantity': qtyHolder,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadStock();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _syncBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppTheme.navy.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.goldColor.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          if (_syncing)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const Icon(Icons.lan_outlined, size: 18, color: AppTheme.goldDeep),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _syncStatus ?? 'Doctor PCs: ${_doctors.length} configured',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    if (_syncError != null)
                      Expanded(
                        child: Text(
                          _syncError!,
                          style: const TextStyle(fontSize: 11, color: AppTheme.errorColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.goldColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'v24',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.goldDeep),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Manage Doctor PCs',
            visualDensity: VisualDensity.compact,
            onPressed: _manageDoctors,
            icon: const Icon(Icons.settings_ethernet, size: 18),
          ),
          IconButton(
            tooltip: 'Sync prescriptions from all Doctor PCs',
            visualDensity: VisualDensity.compact,
            onPressed: _syncing ? null : _syncFromAllDoctors,
            icon: const Icon(Icons.sync, size: 18),
          ),
        ],
      ),
    );
  }
}