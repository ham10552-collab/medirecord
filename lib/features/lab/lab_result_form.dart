import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/database/database_helper.dart';
import '../../core/network/patient_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_storage.dart';
import '../../core/utils/lab_tests.dart';
import '../../shared/widgets/luxury_figures.dart';

/// The lab technician enters a numeric value per ordered test; the normal
/// range/unit come from the catalog (editable). Out-of-range values are
/// flagged abnormal automatically. Extra tests can be added manually.
/// The whole request is then posted back to the requesting doctor.
class LabResultForm extends StatefulWidget {
  final Map<String, dynamic> request;

  const LabResultForm({super.key, required this.request});

  @override
  State<LabResultForm> createState() => _LabResultFormState();
}

class _LabResultFormState extends State<LabResultForm> {
  late List<Map<String, dynamic>> _items;
  late final Map<int, TextEditingController> _valueCtrls;
  late final Map<int, TextEditingController> _rangeCtrls;
  late final Map<int, TextEditingController> _unitCtrls;
  late final Map<int, TextEditingController> _noteCtrls;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _items = ((widget.request['items'] as List?) ?? const [])
        .map((i) => Map<String, dynamic>.from((i as Map).cast<String, dynamic>()))
        .toList();
    // Autofill catalog defaults for any test that lacks them.
    for (final it in _items) {
      final def = labTestLookup(it['test_name'] as String? ?? '');
      it['normal_range'] ??= def.normalRange;
      it['unit'] ??= def.unit;
      it['value'] ??= '';
      it['abnormal'] ??= false;
    }
    _valueCtrls = {for (var i = 0; i < _items.length; i++) i: TextEditingController(text: _items[i]['value'] as String? ?? '')};
    _rangeCtrls = {for (var i = 0; i < _items.length; i++) i: TextEditingController(text: _items[i]['normal_range'] as String? ?? '')};
    _unitCtrls = {for (var i = 0; i < _items.length; i++) i: TextEditingController(text: _items[i]['unit'] as String? ?? '')};
    _noteCtrls = {for (var i = 0; i < _items.length; i++) i: TextEditingController(text: _items[i]['note'] as String? ?? '')};
  }

  @override
  void dispose() {
    for (final c in _valueCtrls.values) c.dispose();
    for (final c in _rangeCtrls.values) c.dispose();
    for (final c in _unitCtrls.values) c.dispose();
    for (final c in _noteCtrls.values) c.dispose();
    super.dispose();
  }

  bool _isAbnormal(String value, String range) {
    final v = double.tryParse(value.trim().replaceAll(',', '.'));
    if (v == null || range.trim().isEmpty) return false;
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*[-–—~to]\s*(\d+(?:\.\d+)?)').firstMatch(range);
    if (match == null) {
      // Single-side ranges like "> 10" or "0 - 5"
      final gt = RegExp(r'>\s*(\d+(?:\.\d+)?)').firstMatch(range);
      if (gt != null) return v > double.parse(gt.group(1)!);
      final lt = RegExp(r'<\s*(\d+(?:\.\d+)?)').firstMatch(range);
      if (lt != null) return v > double.parse(lt.group(1)!);
      return false;
    }
    final lo = double.tryParse(match.group(1)!);
    final hi = double.tryParse(match.group(2)!);
    if (lo == null || hi == null) return false;
    return v < lo || v > hi;
  }

  void _addCustomTest() {
    final nameCtrl = TextEditingController();
    final rangeCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add custom test'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Test name *'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: rangeCtrl,
                      decoration: const InputDecoration(labelText: 'Normal range'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: unitCtrl,
                      decoration: const InputDecoration(labelText: 'Unit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              setState(() {
                final idx = _items.length;
                _items.add({
                  'test_name': name,
                  'note': '',
                  'value': '',
                  'normal_range': rangeCtrl.text.trim(),
                  'unit': unitCtrl.text.trim(),
                  'abnormal': false,
                  'manual': true,
                });
                _valueCtrls[idx] = TextEditingController();
                _rangeCtrls[idx] = TextEditingController(text: rangeCtrl.text.trim());
                _unitCtrls[idx] = TextEditingController(text: unitCtrl.text.trim());
                _noteCtrls[idx] = TextEditingController();
              });
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<String> _technicianName() async {
    final saved = (await AppStorage.read('lab_technician_name'))?.trim() ?? '';
    if (saved.isNotEmpty) return saved;
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Lab technician name', hintText: 'e.g. Sara'),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              final n = ctrl.text.trim();
              if (n.isNotEmpty) Navigator.pop(ctx, n);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await AppStorage.write('lab_technician_name', name);
    }
    return name ?? 'Technician';
  }

  Future<void> _send() async {
    for (var i = 0; i < _items.length; i++) {
      final value = _valueCtrls[i]!.text.trim();
      _items[i]['value'] = value;
      _items[i]['normal_range'] = _rangeCtrls[i]!.text.trim();
      _items[i]['unit'] = _unitCtrls[i]!.text.trim();
      _items[i]['note'] = _noteCtrls[i]!.text.trim();
      _items[i]['abnormal'] = _isAbnormal(value, _items[i]['normal_range'] as String? ?? '');
    }
    setState(() => _error = null);

    final host = (widget.request['doctor_host'] as String? ?? '').trim();
    if (host.isEmpty) {
      setState(() => _error = 'This request has no doctor address - cannot return results.');
      return;
    }
    final parts = host.split(':');
    final ip = parts[0];
    final port = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 9876;

    setState(() => _sending = true);
    try {
      final completed = {
        ...widget.request,
        'items': _items,
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
        'lab_technician': await _technicianName(),
      };
      final db = DatabaseHelper();
      await db.upsertLabRequest(completed);
      final resp = await PatientClient.sendLabResult(completed, ip, port);
      if (!mounted) return;
      final ok = resp['status'] == 'ok';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'Results returned to the doctor (${widget.request['patient_name'] ?? 'patient'})'
            : 'Saved locally, but could not reach the doctor: ${resp['message'] ?? 'network error'}'),
        backgroundColor: ok ? AppTheme.successColor : AppTheme.warningColor,
        duration: const Duration(seconds: 6),
      ));
      if (ok) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lab Results Entry'),
        actions: [
          IconButton(
            tooltip: 'Add custom test',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _addCustomTest,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const MedicalCrossFigure(size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r['patient_name'] ?? 'Unknown',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    Text(
                      'Dr. ${r['doctor_name'] ?? '-'} • ordered ${(r['requested_at'] as String? ?? '').substring(0, 10)}',
                      style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const GoldDivider(),
          const SizedBox(height: 10),
          for (var i = 0; i < _items.length; i++) _buildTestRow(i),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppTheme.errorColor, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send, size: 18),
            label: const Text('Return Results to Doctor'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: AppTheme.successColor,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Out-of-range values are automatically flagged abnormal.',
            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTestRow(int i) {
    final it = _items[i];
    final value = _valueCtrls[i]!.text.trim();
    final abnormal = _isAbnormal(value, _rangeCtrls[i]!.text.trim());
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.biotech, size: 16, color: AppTheme.primaryColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    it['test_name'] ?? 'Test',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                if (abnormal)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('ABNORMAL',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.errorColor)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: _valueCtrls[i],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-<>, ]')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Value *',
                      isDense: true,
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: abnormal ? AppTheme.errorColor : Colors.grey.shade300),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: _rangeCtrls[i],
                    decoration: const InputDecoration(labelText: 'Normal range', isDense: true, border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _unitCtrls[i],
                    decoration: const InputDecoration(labelText: 'Unit', isDense: true, border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrls[i],
              decoration: const InputDecoration(labelText: 'Note (optional)', isDense: true, border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
    );
  }
}