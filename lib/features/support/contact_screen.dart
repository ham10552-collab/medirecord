import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/luxury_figures.dart';

const String kSupportPhone = '07706268194';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  void _copy(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard'), backgroundColor: AppTheme.successColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LuxNavyBackdrop(
        showBack: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LuxBrandHeader(
              title: 'Support & Contact',
              tagline: 'WE ARE HERE TO HELP YOU',
            ),
            const SizedBox(height: 28),
            _ContactCard(
              icon: Icons.phone,
              title: 'Phone / WhatsApp',
              subtitle: kSupportPhone,
              trailingLabel: 'Copy number',
              onTap: () => _copy(context, kSupportPhone, 'Phone number'),
            ),
            const SizedBox(height: 14),
            _ContactCard(
              icon: Icons.support_agent,
              title: 'Technical Support',
              subtitle: 'Call or WhatsApp us for help with activation, network setup, or any issue.',
              onTap: () => _copy(context, kSupportPhone, 'Phone number'),
            ),
            const SizedBox(height: 28),
            const Text(
              'Mention your Device ID (shown in the License screen) when you contact us, so we can help you faster.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.goldLight, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailingLabel;
  final VoidCallback onTap;
  const _ContactCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailingLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LuxHover(
      onTap: onTap,
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF101D45), Color(0xFF0B1430)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.goldColor.withValues(alpha: 0.45), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.goldGradient,
                boxShadow: [BoxShadow(color: AppTheme.goldDeep.withValues(alpha: 0.4), blurRadius: 10)],
              ),
              child: Icon(icon, color: AppTheme.navyDeep, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.champagneLight,
                      fontSize: 15,
                      fontFamily: AppTheme.displayFont,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (trailingLabel != null)
              Text(
                trailingLabel!,
                style: const TextStyle(color: AppTheme.goldColor, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            const Icon(Icons.chevron_right, color: AppTheme.goldColor),
          ],
        ),
      ),
    );
  }
}
