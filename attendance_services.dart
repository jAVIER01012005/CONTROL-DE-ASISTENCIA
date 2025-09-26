import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:conttrol_asistencia/services/http_services.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../models/attendance.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class AttendanceService with ChangeNotifier {
  final HttpService _httpService = HttpService();

  // Estado
  bool _isLoading = false;
  String? _lastError;
  List<AttendanceModel> _cachedAttendances = [];
  Map<String, dynamic>? _todayAttendance;
  final StreamController<Map<String, dynamic>?> _attendanceController =
      StreamController<Map<String, dynamic>?>.broadcast();

  // Token y URL base para exportación
  String? _token;
  String _baseUrl = 'http://192.168.39.191:8000/api';

  // método para obtener el estado
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  List<AttendanceModel> get cachedAttendances => _cachedAttendances;
  Map<String, dynamic>? get todayAttendance => _todayAttendance;

  @override
  void dispose() {
    _attendanceController.close();
    super.dispose();
  }

  // Método para establecer el token
  void setToken(String token) {
    _token = token;
    notifyListeners();
  }

  // Método para establecer la URL base
  void setBaseUrl(String url) {
    _baseUrl = url;
    notifyListeners();
  }

  // Método  para manejar errores
  void _setError(String error) {
    _lastError = error;
    debugPrint('Attendance Service Error: $error');
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _clearError() {
    _lastError = null;
    notifyListeners();
  }

  // Marcar entrada
  Future<AttendanceResult> checkIn({
    required int userId,
    required String userName,
    required double latitude,
    required double longitude,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Validacion de  parámetros
      if (userName.trim().isEmpty) {
        throw Exception('Nombre de usuario no puede estar vacío');
      }

      if (latitude.abs() > 90 || longitude.abs() > 180) {
        throw Exception('Coordenadas inválidas');
      }

      final response = await _httpService.post('/attendance/checkin', data: {
        'user_id': userId,
        'user_name': userName.trim(),
        'latitude': latitude,
        'longitude': longitude,
      });

      if (response.statusCode == 201) {
        // Actualizar cache local y notificar al stream
        await _refreshTodayAttendance(userId);
        _notifyStream();
        return AttendanceResult.success('Entrada marcada correctamente');
      } else {
        final errorMsg = response.data?['error'] ?? 'Error al marcar entrada';
        _setError(errorMsg);
        return AttendanceResult.error(errorMsg);
      }
    } catch (e) {
      final errorMsg = 'Error al marcar entrada: ${e.toString()}';
      _setError(errorMsg);
      return AttendanceResult.error(errorMsg);
    } finally {
      _setLoading(false);
    }
  }

  // Marcar salida
  Future<AttendanceResult> checkOut({
    required int attendanceId,
    required double latitude,
    required double longitude,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      if (latitude.abs() > 90 || longitude.abs() > 180) {
        throw Exception('Coordenadas inválidas');
      }

      final response =
          await _httpService.put('/attendance/checkout/$attendanceId', data: {
        'latitude': latitude,
        'longitude': longitude,
      });

      if (response.statusCode == 200) {
        // Obtener userId antes de actualizar el estado
        final userId = _todayAttendance?['user_id'];
        if (userId != null) {
          await _refreshTodayAttendance(userId);
        }
        _notifyStream();
        return AttendanceResult.success('Salida marcada correctamente');
      } else {
        final errorMsg = response.data?['error'] ?? 'Error al marcar salida';
        _setError(errorMsg);
        return AttendanceResult.error(errorMsg);
      }
    } catch (e) {
      final errorMsg = 'Error al marcar salida: ${e.toString()}';
      _setError(errorMsg);
      return AttendanceResult.error(errorMsg);
    } finally {
      _setLoading(false);
    }
  }

  Future<dynamic> getTodayAttendance(int userId,
      {bool forceRefresh = false}) async {
    _setLoading(true);
    _clearError();

    try {
      final response =
          await _httpService.get('/attendance/latest-pending/$userId');

      if (response.statusCode == 200) {
        _todayAttendance = response.data;
        return response.data;
      } else if (response.statusCode == 404) {
        _todayAttendance = null;
        return null;
      } else {
        _setError('Error obteniendo asistencia de hoy');
        return null;
      }
    } catch (e) {
      _setError('Error de conexión: ${e.toString()}');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<List<AttendanceModel>> getAttendanceHistory(int userId,
      {int limit = 30, int offset = 0}) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _httpService
          .get('/attendance/user/$userId?limit=$limit&offset=$offset');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final List<dynamic> attendancesData = data['attendances'] ?? [];

        final List<AttendanceModel> attendances = attendancesData
            .map((item) => AttendanceModel.fromJson(item))
            .toList();

        _cachedAttendances = attendances;
        return attendances;
      } else {
        _setError('Error obteniendo historial de asistencias');
        return [];
      }
    } catch (e) {
      _setError('Error de conexión: ${e.toString()}');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  // Obtener asistencias por rango de fechas
  Future<List<AttendanceModel>> getAttendanceByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    int? userId,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final String startDateStr = _formatDate(startDate);
      final String endDateStr = _formatDate(endDate);

      String url =
          '/attendance/date-range?start_date=$startDateStr&end_date=$endDateStr';
      if (userId != null) {
        url += '&user_id=$userId';
      }

      final response = await _httpService.get(url);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final List<dynamic> attendancesData = data['attendances'] ?? [];

        return attendancesData
            .map((item) => AttendanceModel.fromJson(item))
            .toList();
      } else {
        _setError('Error obteniendo asistencias por fecha');
        return [];
      }
    } catch (e) {
      _setError('Error de conexión: ${e.toString()}');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  // ✅ VERSIÓN SIMPLIFICADA CORREGIDA - SOLO MÓVIL
  Future<void> exportToExcel({
    required DateTime startDate,
    required DateTime endDate,
    int? userId,
    required BuildContext context,
  }) async {
    // Verificar mounted al inicio
    if (!context.mounted) return;

    try {
      if (_token == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No hay sesión activa')),
          );
        }
        return;
      }

      // Mostrar loading con verificación de mounted
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(width: 12),
                Text('Generando reporte...'),
              ],
            ),
          ),
        );
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/reports/generate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'start_date': _formatDate(startDate),
          'end_date': _formatDate(endDate),
          'user_id': userId,
          'format': 'excel',
        }),
      );

      // Ocultar snackbar
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      if (response.statusCode == 200) {
        //  PARA ANDROID/IOS
        final directory = await getApplicationDocumentsDirectory();
        final fileName =
            'reporte_asistencias_${_formatDate(startDate)}_a_${_formatDate(endDate)}.xlsx';
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        await OpenFilex.open(file.path);

        // Mostrar éxito con verificación de mounted
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Reporte descargado: $fileName')),
          );
        }
      } else {
        // Mostrar error con verificación de mounted
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${response.statusCode}')),
          );
        }
      }
    } catch (error) {
      // Ocultar snackbar y mostrar error con verificación de mounted
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    }
  }

  //  para formatear fecha
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  //  para refrescar la asistencia de hoy
  Future<void> _refreshTodayAttendance(int userId) async {
    try {
      await getTodayAttendance(userId, forceRefresh: true);
    } catch (e) {
      debugPrint('Error refrescando asistencia de hoy: $e');
    }
  }

  // para notificar al stream
  void _notifyStream() {
    _attendanceController.add(_todayAttendance);
  }

  //  para escuchar cambios en la asistencia
  Stream<Map<String, dynamic>?> get attendanceStream =>
      _attendanceController.stream;

  // Limpiar cache
  void clearCache() {
    _cachedAttendances.clear();
    _todayAttendance = null;
    _lastError = null;
    notifyListeners();
  }

  // ✅ ELIMINADOS LOS MÉTODOS NO UTILIZADOS:
  // _showLoadingSnackBar, _showSuccessSnackBar, _showErrorSnackBar
  // fueron removidos porque no se utilizan en el código actual
}

// manejo de  resultados de operaciones de asistencia
class AttendanceResult {
  final bool success;
  final String message;
  final AttendanceModel? attendance;

  AttendanceResult._({
    required this.success,
    required this.message,
    this.attendance,
  });

  factory AttendanceResult.success(String message,
      {AttendanceModel? attendance}) {
    return AttendanceResult._(
      success: true,
      message: message,
      attendance: attendance,
    );
  }

  factory AttendanceResult.error(String message) {
    return AttendanceResult._(
      success: false,
      message: message,
    );
  }
}
