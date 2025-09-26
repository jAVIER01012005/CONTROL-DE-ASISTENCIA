import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class HttpService {
  late Dio _dio;
  static const String _tokenKey = 'auth_token';

  HttpService() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: Duration(seconds: 15),
      receiveTimeout: Duration(seconds: 15),
      headers: ApiConfig.headers,
    ));

    //  interceptores para logging
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        print('🌐 Enviando petición: ${options.method} ${options.uri}');
        print('📋 Headers: ${options.headers}');
        if (options.data != null) {
          print('📦 Body: ${options.data}');
        }

        final token = await getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
          print('🔑 Token agregado a la petición');
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        print('✅ Respuesta exitosa: ${response.statusCode}');
        print('📄 Data: ${response.data}');
        handler.next(response);
      },
      onError: (error, handler) {
        print('❌ Error de conexión: ${error.message}');
        print('📡 URL: ${error.requestOptions.uri}');
        if (error.response != null) {
          print('📊 Status: ${error.response?.statusCode}');
          print('📋 Response: ${error.response?.data}');
        }
        handler.next(error);
      },
    ));
  }

  // Obtener token
  Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (e) {
      print('❌ Error obteniendo token: $e');
      return null;
    }
  }

  // Guardar token
  Future<void> saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      print('💾 Token guardado correctamente');
    } catch (e) {
      print('❌ Error guardando token: $e');
    }
  }

  // Limpiar token
  Future<void> clearToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      print('🗑️ Token eliminado');
    } catch (e) {
      print('❌ Error eliminando token: $e');
    }
  }

  // GET request
  Future<Response> get(String path,
      {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // POST request
  Future<Response> post(String path, {dynamic data}) async {
    try {
      return await _dio.post(path, data: data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // PUT request
  Future<Response> put(String path, {dynamic data}) async {
    try {
      return await _dio.put(path, data: data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // DELETE request
  Future<Response> delete(String path) async {
    try {
      return await _dio.delete(path);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Manejo de errores
  String _handleError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Tiempo de espera agotado. Verifica tu conexión.';
        case DioExceptionType.badResponse:
          return _parseErrorMessage(error.response);
        case DioExceptionType.cancel:
          return 'Petición cancelada';
        default:
          return 'Error de conexión. Verifica tu conexión a internet.';
      }
    }
    return 'Error inesperado: $error';
  }

  String _parseErrorMessage(Response? response) {
    if (response?.data != null && response!.data is Map) {
      final data = response.data as Map<String, dynamic>;
      return data['message'] ?? data['error'] ?? 'Error del servidor';
    }
    return 'Error del servidor (${response?.statusCode})';
  }
}
