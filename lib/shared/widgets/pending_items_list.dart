import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class PendingItemsList extends StatelessWidget {
  final int itemCount;
  final IconData Function(int index) iconBuilder;
  final Color Function(int index)? iconColorBuilder;
  final String Function(int index) labelBuilder;
  final String? Function(int index)? subtitleBuilder;
  final void Function(int index) onRemove;

  const PendingItemsList({
    super.key,
    required this.itemCount,
    required this.iconBuilder,
    required this.labelBuilder,
    required this.onRemove,
    this.iconColorBuilder,
    this.subtitleBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 170),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shrinkWrap: true,
        itemCount: itemCount,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 44),
        itemBuilder: (context, i) => ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: (iconColorBuilder?.call(i) ?? AppTheme.primaryColor).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(iconBuilder(i), size: 17, color: iconColorBuilder?.call(i) ?? AppTheme.primaryColor),
          ),
          title: Text(
            labelBuilder(i),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
          subtitle: subtitleBuilder != null
              ? Text(subtitleBuilder!(i) ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5))
              : null,
          trailing: IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Remove',
            color: AppTheme.errorColor,
            onPressed: () => onRemove(i),
          ),
        ),
      ),
    );
  }
}