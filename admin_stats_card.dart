// admin_stats_card.dart - Updated version
import 'package:conttrol_asistencia/models/attendance.dart';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class AdminStatsCard extends StatelessWidget {
  final List<AttendanceModel> attendances;

  const AdminStatsCard({
    super.key,
    required this.attendances,
  });

  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen del Día',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // estadísticas
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                _buildStatItem(
                  'Total Empleados',
                  stats['total'].toString(),
                  Icons.people,
                  AppTheme.primaryColor,
                ),
                _buildStatItem(
                  'Puntuales',
                  stats['onTime'].toString(),
                  Icons.check_circle,
                  AppTheme.successColor,
                ),
                _buildStatItem(
                  'Retardos',
                  stats['late'].toString(),
                  Icons.access_time,
                  AppTheme.warningColor,
                ),
                _buildStatItem(
                  'Sin Salida',
                  stats['incomplete'].toString(),
                  Icons.warning,
                  AppTheme.errorColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Map<String, int> _calculateStats() {
    int total = attendances.length;
    int onTime = attendances.where((a) => a.status == 'on-time').length;
    int late = attendances.where((a) => a.status == 'late').length;
    int incomplete = attendances.where((a) => !a.isComplete).length;

    return {
      'total': total,
      'onTime': onTime,
      'late': late,
      'incomplete': incomplete,
    };
  }
}
