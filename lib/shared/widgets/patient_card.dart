import 'package:flutter/material.dart';
import '../../shared/models/patient.dart';
import '../../core/theme/app_theme.dart';

class PatientCard extends StatelessWidget {
  final Patient patient;
  final VoidCallback onTap;

  const PatientCard({super.key, required this.patient, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final initial1 = patient.firstName.isNotEmpty ? patient.firstName[0] : '?';
    final initial2 = patient.lastName.isNotEmpty ? patient.lastName[0] : '?';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                child: Text(
                  '$initial1$initial2',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.fullName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
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
                      Text(
                        patient.phone!,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      ],
    );
  }
}
