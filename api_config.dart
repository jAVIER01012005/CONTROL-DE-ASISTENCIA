class ApiConfig {
  static String get baseUrl {
    // Siempre usar la IP pública del Droplet en DigitalOcean
    return 'http://143.198.14.214:8000/api';
  }

  // --- Autenticación ---
  static String get login => '$baseUrl/auth/login';
  static String get register => '$baseUrl/auth/register';
  static String get logout => '$baseUrl/auth/logout';
  static String get userProfile => '$baseUrl/auth/profile';

  // --- Asistencia ---
  static String get checkIn => '$baseUrl/attendance/checkin';
  static String get checkOut => '$baseUrl/attendance/checkout';
  static String get todayAttendance => '$baseUrl/attendance/today';
  static String get userAttendances => '$baseUrl/attendance/user';
  static String get allAttendances => '$baseUrl/attendance/all';
  static String get attendancesByDate => '$baseUrl/attendance/date-range';
  static String get userStats => '$baseUrl/attendance/stats';

  // --- Configuración ---
  static String get officeLocation => '$baseUrl/settings/office-location';
  static String get workSchedule => '$baseUrl/settings/work-schedule';

  // --- Headers ---
  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Token dinámico en headers
  static Map<String, String> getAuthHeaders(String token) {
    return {
      ...headers,
      'Authorization': 'Bearer $token',
    };
  }

