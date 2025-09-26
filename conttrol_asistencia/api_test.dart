import 'package:conttrol_asistencia/services/http_services.dart';

class ApiTester {
  static final HttpService _httpService = HttpService();

  static Future<void> testAllEndpoints() async {
    try {
      print('🧪 Probando conectividad con API...');

      // Test health endpoint
      final healthResponse = await _httpService.get('/health');
      print('✅ Health: ${healthResponse.statusCode}');

      // Test database
      final dbResponse = await _httpService.get('/test-db');
      print('✅ Database: ${dbResponse.statusCode}');

      // Test office location
      final locationResponse =
          await _httpService.get('/settings/office-location');
      print('✅ Office Location: ${locationResponse.statusCode}');

      print('🎉 Todas las pruebas pasaron!');
    } catch (e) {
      print('❌ Error en pruebas: $e');
    }
  }
}
