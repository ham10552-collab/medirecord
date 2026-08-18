import 'package:flutter/material.dart';
import '../../shared/models/patient.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/luxury_figures.dart';

class PatientCard extends StatelessWidget {
  final Patient patient;
  final VoidCallback onTap;
  final Widget? action;

  const PatientCard({
    super.key,
    required this.patient,
    required this.onTap,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final initial1 = patient.firstName.isNotEmpty ? patient.firstName[0] : '?';
    final initial2 = patient.lastName.isNotEmpty ? patient.lastName[0] : '?';
    return LuxHover(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.goldColor.withValues(alpha: 0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.goldGradient,
                ),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: AppTheme.navy,
                  child: Text(
                    '$initial1$initial2',
                    style: const TextStyle(
                      color: AppTheme.champagneLight,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      fontFamily: AppTheme.displayFont,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.navy,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        _infoChip(Icons.person, patient.gender),
                        const SizedBox(width: 12),
                        _infoChip(Icons.calendar_today, '${patient.age}y'),
                        if (patient.bloodGroup != null) ...[
                          const SizedBox(width: 12),
                          _infoChip(Icons.donut_small, patient.bloodGroup!),
                        ],
                      ],
                    ),
                    if (patient.phone != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 13, color: AppTheme.primaryColor),
                          const SizedBox(width: 4),
                          Text(
                            patient.phone!,
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (action != null) action!,
              const SparkleStar(size: 12),
              const SizedBox(width: 10),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.champagne.withValues(alpha: 0.12),
                ),
                child: const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppTheme.goldDeep,
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.goldDeep),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5)),
      ],
    );
  }
}