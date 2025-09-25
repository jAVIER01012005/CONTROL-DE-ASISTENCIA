import 'package:conttrol_asistencia/services/attendance_services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/auth_service.dart';
import 'services/location_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/employee_home_screen.dart';
import 'screens/admin_home_screen.dart';
import 'utils/app_theme.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_ES', null);
  await _requestPermissions();

  // Verificacar la conectividad
  _testBasicConnectivity();

  runApp(MyApp());
}

Future<void> _requestPermissions() async {
  var locationStatus = await Permission.location.status;
  if (!locationStatus.isGranted) {
    locationStatus = await Permission.location.request();

    if (locationStatus.isPermanentlyDenied) {
      print('Los permisos de ubicación están denegados permanentemente');
    }
    if (locationStatus.isPermanentlyDenied) {
      await openAppSettings(); // Redirige a configuración
    }
  }

  await Permission.notification.request();
  await Permission.storage.request();
}

// testear conectividad
void _testBasicConnectivity() {
  print('🔍 Verificando configuración de API...');
  print('🌐 URL base: http://192.168.39.191:8000/api');
  print('📱 Asegúrate de que el servidor esté ejecutándose');
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => AttendanceService()),
        ChangeNotifierProvider(create: (_) => LocationService()),
      ],
      child: MaterialApp(
        title: 'Control de Asistencia',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        routes: {
          '/': (context) => SplashScreen(),
          '/login': (context) => LoginScreen(),
          '/employee-home': (context) => EmployeeHomeScreen(),
          '/admin-home': (context) => AdminHomeScreen(),
        },
      ),
    );
  }
}
