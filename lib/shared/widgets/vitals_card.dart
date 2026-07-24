import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.monitor_heart, color: AppTheme.primaryColor, size: 20),
                SizedBox(width: 8),
                Text('Vital Signs',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
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
      ),
    );
  }

  Widget _vitalItem(IconData icon, String label, String value, String unit) {
    return SizedBox(
      width: 90,
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text('$label ($unit)', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}
