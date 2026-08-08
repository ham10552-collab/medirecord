import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/luxury_figures.dart';

class VitalsCard extends StatelessWidget {
  final int? systolic;
  final int? diastolic;
  final int? heartRate;
  final double? temperature;
  final int? respiratoryRate;
  final int? oxygenSaturation;
  final double? weight;
  final double? height;

  const VitalsCard({
    super.key,
    this.systolic,
    this.diastolic,
    this.heartRate,
    this.temperature,
    this.respiratoryRate,
    this.oxygenSaturation,
    this.weight,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              MedicalCrossFigure(size: 12, gold: true),
              SizedBox(width: 10),
              Text(
                'Vital Signs',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navy,
                  fontFamily: AppTheme.displayFont,
                  letterSpacing: 0.3,
                ),
              ),
              Spacer(),
              SparkleStar(size: 10),
            ],
          ),
          const SizedBox(height: 4),
          const GoldDivider(thickness: 0.8),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 14,
            children: [
              _vitalItem(Icons.compress, 'BP',
                  systolic != null ? '$systolic/$diastolic' : '-', 'mmHg'),
              _vitalItem(Icons.favorite, 'HR', heartRate?.toString() ?? '-', 'bpm'),
              _vitalItem(Icons.thermostat, 'Temp',
                  temperature?.toStringAsFixed(1) ?? '-', '°C'),
              _vitalItem(Icons.air, 'RR', respiratoryRate?.toString() ?? '-', '/min'),
              _vitalItem(Icons.monitor, 'SpO2',
                  oxygenSaturation?.toString() ?? '-', '%'),
              _vitalItem(Icons.monitor_weight, 'Wt', weight?.toString() ?? '-', 'kg'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vitalItem(IconData icon, String label, String value, String unit) {
    return SizedBox(
      width: 90,
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.1),
                  AppTheme.champagne.withValues(alpha: 0.16),
                ],
              ),
              border: Border.all(color: AppTheme.goldColor.withValues(alpha: 0.35), width: 1),
            ),
            child: Icon(icon, size: 18, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppTheme.navy,
            ),
          ),
          Text(
            '$label ($unit)',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}