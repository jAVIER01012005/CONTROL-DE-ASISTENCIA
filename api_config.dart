import 'dart:io';

class ApiConfig {
  static String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api';
    } else if (Platform.isIOS) {
      // iOS Simulator y dispositivos físicos deben usar la IP de tu Mac
      return 'http://172.20.10.2:8000/api';
    } else {
      return 'http://localhost:8000/api';
    }
  }

  // autenticación
  static String get login => '$baseUrl/auth/login';
  static String get register => '$baseUrl/auth/register';
  static String get logout => '$baseUrl/auth/logout';
  static String get userProfile => '$baseUrl/auth/profile';

  // asistencia
  static String get checkIn => '$baseUrl/attendance/checkin';
  static String get checkOut => '$baseUrl/attendance/checkout';
  static String get todayAttendance => '$baseUrl/attendance/today';
  static String get userAttendances => '$baseUrl/attendance/user';
  static String get allAttendances => '$baseUrl/attendance/all';
  static String get attendancesByDate => '$baseUrl/attendance/date-range';
  static String get userStats => '$baseUrl/attendance/stats';

  // configuración
  static String get officeLocation => '$baseUrl/settings/office-location';
  static String get workSchedule => '$baseUrl/settings/work-schedule';

  // Headers
  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // token
  static Map<String, String> getAuthHeaders(String token) {
    return {
      ...headers,
      'Authorization': 'Bearer $token',
    };
  }
}
