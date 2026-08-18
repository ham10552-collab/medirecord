import 'package:flutter/material.dart';
import '../../core/database/database_helper.dart';
import '../../core/theme/app_theme.dart';

/// Opens the duplicate-patients finder used by both the doctor's patient list
/// and the secretary screen. Returns true when at least one group was merged.
///
/// The dialog keeps itself live: every merged group disappears from the list
/// immediately, and the dialog closes when no groups are left.
Future<bool> showDuplicateFinder(BuildContext context) async {
  List<List<Map<String, dynamic>>> groups = [];
  try {
    groups = await DatabaseHelper().findDuplicatePatients();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not scan patients: $e'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
    return false;
  }
  if (!context.mounted) return false;
  if (groups.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No duplicate patients found - all names are unique'),
        backgroundColor: Colors.green,
      ),
    );
    return false;
  }

  var mergedAny = false;

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        void removeGroup(List<Map<String, dynamic>> group) {
          mergedAny = true;
          setDialogState(() => groups.remove(group));
        }

        void finishMerging() {
          ScaffoldMessenger.of(dialogContext).showSnackBar(
            SnackBar(
              content: Text(
                groups.isEmpty
                    ? 'All duplicate groups merged'
                    : 'Duplicates merged successfully',
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(dialogContext, true);
        }

        Future<void> mergeAll() async {
          final db = DatabaseHelper();
          for (final group in List<List<Map<String, dynamic>>>.from(groups)) {
            if (!groups.contains(group)) continue;
            final keepId = group.first['id'] as String?;
            if (keepId == null) continue;
            var merged = 0;
            try {
              for (final m in group.skip(1)) {
                merged += await db.mergePatients(keepId, m['id'] as String);
              }
            } catch (_) {
              continue;
            }
            if (merged > 0) removeGroup(group);
          }
          if (groups.isEmpty) finishMerging();
        }

        return AlertDialog(
          backgroundColor: AppTheme.navyDeep,
          title: Row(
            children: [
              const Icon(Icons.call_split, color: AppTheme.champagne),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${groups.length} duplicate group(s) found',
                    style: const TextStyle(color: AppTheme.champagneLight)),
              ),
              if (groups.length > 1)
                TextButton.icon(
                  onPressed: mergeAll,
                  icon: const Icon(Icons.join_full, size: 16),
                  label: const Text('Merge All'),
                ),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final group in groups)
                  _DuplicateGroupCard(
                    group: group,
                    onMerged: () {
                      removeGroup(group);
                      if (groups.isEmpty) finishMerging();
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, mergedAny),
              child: const Text('Close', style: TextStyle(color: AppTheme.champagne)),
            ),
          ],
        );
      },
    ),
  );

  return result ?? mergedAny;
}

class _DuplicateGroupCard extends StatefulWidget {
  final List<Map<String, dynamic>> group;
  final VoidCallback onMerged;
  const _DuplicateGroupCard({required this.group, required this.onMerged});

  @override
  State<_DuplicateGroupCard> createState() => _DuplicateGroupCardState();
}

class _DuplicateGroupCardState extends State<_DuplicateGroupCard> {
  String? _keepId;
  bool _busy = false;

  String _label(Map<String, dynamic> m) {
    final name = '${m['first_name'] ?? ''} ${m['last_name'] ?? ''}'.trim();
    final phone = (m['phone'] as String? ?? '').isNotEmpty ? '  ${m['phone']}' : '';
    final age = m['age'] != null ? '  ${m['age']} yrs' : '';
    return '$name$age$phone';
  }

  Future<void> _merge() async {
    final keepId = _keepId ?? (widget.group.first['id'] as String);
    final removeIds = widget.group
        .map((m) => m['id'] as String)
        .where((id) => id != keepId)
        .toList();
    if (removeIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.navyDeep,
        title: const Text('Merge patients?', style: TextStyle(color: AppTheme.champagneLight)),
        content: Text(
          'All history, examinations, medications, prescriptions and bookings '
          'of ${removeIds.length} patient(s) will move to the one you keep, then the '
          'duplicate(s) will be deleted permanently.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Merge', style: TextStyle(color: AppTheme.champagne)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      final db = DatabaseHelper();
      var merged = 0;
      for (final id in removeIds) {
        merged += await db.mergePatients(keepId, id);
      }
      if (!mounted) return;
      if (merged == 0) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Merge failed: patients were not found. Refresh and try again.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
      setState(() => _busy = false);
      widget.onMerged();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Merge failed: $e'), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF101D45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.goldColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final m in widget.group)
            RadioListTile<String>(
              dense: true,
              value: m['id'] as String,
              groupValue: _keepId ?? (widget.group.first['id'] as String),
              onChanged: _busy ? null : (v) => setState(() => _keepId = v),
              title: Text(_label(m), style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                m['id'] == _keepId || (_keepId == null && widget.group.first['id'] == m['id'])
                    ? 'KEEP this one'
                    : 'will be merged into the kept one',
                style: TextStyle(
                  color: m['id'] == _keepId || (_keepId == null && widget.group.first['id'] == m['id'])
                      ? Colors.greenAccent
                      : Colors.white54,
                  fontSize: 11,
                ),
              ),
            ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : ElevatedButton.icon(
                    onPressed: _merge,
                    icon: const Icon(Icons.join_full, size: 18),
                    label: const Text('Merge group'),
                  ),
          ),
        ],
      ),
    );
  }
}
