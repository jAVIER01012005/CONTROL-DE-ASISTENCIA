import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'http_services.dart';

class SettingsService with ChangeNotifier {
  final HttpService _httpService = HttpService();

  Map<String, dynamic> _workSchedule = {
    'start_time': '08:00',
    'end_time': '17:00',
    'tolerance_minutes': 15,
    'work_days': [1, 2, 3, 4, 5]
  };

  Map<String, dynamic> get workSchedule => _workSchedule;

  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Cargar horarios locales
      final startTime = prefs.getString('start_time') ?? '08:00';
      final endTime = prefs.getString('end_time') ?? '17:00';
      final tolerance = prefs.getInt('tolerance_minutes') ?? 15;

      _workSchedule = {
        'start_time': startTime,
        'end_time': endTime,
        'tolerance_minutes': tolerance,
        'work_days': [1, 2, 3, 4, 5]
      };

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<bool> saveWorkSchedule(Map<String, dynamic> schedule) async {
    try {
      // Guardar localmente
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('start_time', schedule['start_time']);
      await prefs.setString('end_time', schedule['end_time']);
      await prefs.setInt('tolerance_minutes', schedule['tolerance_minutes']);

      // Actualizar estado local
      _workSchedule = schedule;
      notifyListeners();

      // Guardar en servidor
      final response =
          await _httpService.put('/settings/work-schedule', data: schedule);

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error saving work schedule: $e');
      return false;
    }
  }
}
