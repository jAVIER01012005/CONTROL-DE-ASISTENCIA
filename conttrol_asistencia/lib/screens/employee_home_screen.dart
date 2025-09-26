import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../utils/app_theme.dart';
import '../widgets/location_status_card.dart';
import '../services/attendance_services.dart';
import '../services/http_services.dart';

class EmployeeHomeScreen extends StatefulWidget {
  const EmployeeHomeScreen({super.key});

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  bool _isCheckingIn = false;
  bool _isProcessingCheckout = false; // para manejar el estado de checkout
  List<dynamic> _recentAttendances = [];
  bool _isLoadingAttendances = false;
  dynamic _todayAttendance;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecentAttendances();
      _loadTodayAttendance();

      // Obtener ubicación actual al iniciar
      Future.delayed(Duration(milliseconds: 500), () {
        _getCurrentLocation();
      });
    });
  }

  Future<void> _getCurrentLocation() async {
    final locationService =
        Provider.of<LocationService>(context, listen: false);

    // Obtener posición inmediatamente
    await locationService.getCurrentPosition();

    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {});
      });
    }
  }

  Future<void> _loadTodayAttendance() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final httpService = HttpService();

    if (authService.currentUser != null) {
      try {
        final response = await httpService
            .get('/attendance/latest-pending/${authService.currentUser!.id}');

        if (response.statusCode == 200) {
          setState(() {
            _todayAttendance = response.data;
          });
          debugPrint('Última entrada pendiente: $_todayAttendance');
        } else if (response.statusCode == 404) {
          // verificar si hay entrada pendiente
          setState(() {
            _todayAttendance = null;
          });
        }
      } catch (e) {
        debugPrint('Error loading pending attendance: $e');
        setState(() {
          _todayAttendance = null;
        });
      }
    }
  }

  Future<void> _loadRecentAttendances() async {
    if (!mounted) return;

    setState(() {
      _isLoadingAttendances = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final httpService = HttpService();

    // Obtener el usuario actual
    final currentUser = authService.currentUser;

    if (currentUser == null) {
      if (mounted) {
        setState(() {
          _isLoadingAttendances = false;
          _recentAttendances = [];
        });
      }
      return;
    }

    try {
      // Obtener asistencias del usuario
      final response =
          await httpService.get('/attendance/user/${currentUser.id}?limit=5');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final attendances = data['attendances'] ?? [];

        if (mounted) {
          setState(() {
            _recentAttendances = List<dynamic>.from(attendances);
            _isLoadingAttendances = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingAttendances = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error cargando asistencias: $e');
      if (mounted) {
        setState(() {
          _isLoadingAttendances = false;
        });
      }
      _showErrorSnackBar('Error al cargar historial de asistencias');
    }
  }

  void _showLocationErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ubicación no válida'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCheckInOut() async {
    final locationService =
        Provider.of<LocationService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final attendanceService =
        Provider.of<AttendanceService>(context, listen: false);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Verificar si ya completó su trabajo hoy
    final hasCompletedToday = _recentAttendances.any((attendance) {
      final checkInTime = attendance['check_in_time'] != null
          ? DateTime.parse(attendance['check_in_time'])
          : null;
      final checkOutTime = attendance['check_out_time'] != null
          ? DateTime.parse(attendance['check_out_time'])
          : null;

      if (checkInTime != null) {
        final checkInDate =
            DateTime(checkInTime.year, checkInTime.month, checkInTime.day);
        return checkInDate == today && checkOutTime != null;
      }
      return false;
    });

    if (hasCompletedToday) {
      _showErrorSnackBar('Ya completaste tu jornada hoy');
      return;
    }

    if (_isCheckingIn || _isProcessingCheckout) return;

    setState(() {
      _isCheckingIn = true;
      // Si hay una entrada pendiente, activar el flag de checkout
      if (_todayAttendance != null &&
          _todayAttendance!['check_out_time'] == null) {
        _isProcessingCheckout = true;
      }
    });

    try {
      // Obtener ubicación actual
      await locationService.getCurrentPosition();

      final locationValidation =
          locationService.validateLocationForAttendance();
      if (!locationValidation.isValid) {
        _showLocationErrorDialog(locationValidation.reason);
        return;
      }

      final user = authService.currentUser!;
      final position = locationService.currentPosition!;

      // Verificar si ya tiene una entrada hoy
      if (_todayAttendance == null) {
        // Marcar entrada
        final result = await attendanceService.checkIn(
          userId: user.id,
          userName: user.name,
          latitude: position.latitude,
          longitude: position.longitude,
        );

        if (result.success) {
          _showSuccessSnackBar(result.message);
          await _loadTodayAttendance();
          await _loadRecentAttendances();
        } else {
          _showErrorSnackBar(result.message);
        }
      } else if (_todayAttendance != null &&
          _todayAttendance!['check_out_time'] == null) {
        // Marcar salida
        final result = await attendanceService.checkOut(
          attendanceId: _todayAttendance!['id'],
          latitude: position.latitude,
          longitude: position.longitude,
        );

        if (result.success) {
          _showSuccessSnackBar(result.message);
          // Limpiar el estado local después del checkout hecho
          setState(() {
            _todayAttendance = null;
          });
          await _loadTodayAttendance(); // Recargar datos de hoy
          await _loadRecentAttendances(); // Recargar historial
        } else {
          _showErrorSnackBar(result.message);
        }
      } else {
        _showErrorSnackBar('Ya has completado tu jornada de hoy');
      }
    } catch (e) {
      _showErrorSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingIn = false;
          _isProcessingCheckout = false;
        });
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final checkOutTime =
        _todayAttendance != null ? _todayAttendance['check_out_time'] : null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Control de Asistencia'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _getCurrentLocation();
              _loadRecentAttendances();
              _loadTodayAttendance();
            },
          ),
          PopupMenuButton(
            onSelected: (value) {
              if (value == 'logout') {
                Provider.of<AuthService>(context, listen: false).signOut();
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Cerrar sesión'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _getCurrentLocation();
          await _loadRecentAttendances();
          await _loadTodayAttendance();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Información del usuario
              Consumer<AuthService>(
                builder: (context, authService, child) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¡Hola, ${authService.currentUser?.name ?? 'Usuario'}!',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            DateFormat('EEEE, dd MMMM yyyy', 'es_ES')
                                .format(DateTime.now()),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          if (_todayAttendance != null)
                            Text(
                              checkOutTime == null
                                  ? 'Estado: Entrada marcada'
                                  : 'Estado: Jornada completada',
                              style: TextStyle(
                                color: checkOutTime == null
                                    ? AppTheme.successColor
                                    : AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              SizedBox(height: 16),
              // Estado de ubicación
              LocationStatusCard(),

              const SizedBox(height: 16),
              // Botón principal de entrada/salida
              SizedBox(
                height: 120,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _todayAttendance == null
                        ? AppTheme.successColor
                        : (checkOutTime == null
                            ? AppTheme.errorColor
                            : Colors.grey),
                  ),
                  onPressed: (_isCheckingIn || _isProcessingCheckout)
                      ? null
                      : _handleCheckInOut,
                  child: (_isCheckingIn || _isProcessingCheckout)
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _todayAttendance == null
                                  ? Icons.login
                                  : (checkOutTime == null
                                      ? Icons.logout
                                      : Icons.check_circle),
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _todayAttendance == null
                                  ? 'Marcar Entrada'
                                  : (_todayAttendance['check_out_time'] == null
                                      ? 'Marcar Salida'
                                      : 'Jornada Completada'),
                            )
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // Historial reciente
              Text(
                'Historial Reciente',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),

              if (_isLoadingAttendances)
                const Center(child: CircularProgressIndicator())
              else if (_recentAttendances.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(Icons.history, size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        const Text('No hay registros recientes'),
                      ],
                    ),
                  ),
                )
              else
                ..._recentAttendances.map((attendance) {
                  // Mostrar la información básica
                  final checkInTime = attendance['check_in_time'] != null
                      ? DateTime.parse(attendance['check_in_time'])
                      : null;
                  final checkOutTime = attendance['check_out_time'] != null
                      ? DateTime.parse(attendance['check_out_time'])
                      : null;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(
                          'Asistencia - ${DateFormat('dd/MM/yyyy').format(checkInTime ?? DateTime.now())}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (checkInTime != null)
                            Text(
                                'Entrada: ${DateFormat('HH:mm').format(checkInTime)}'),
                          if (checkOutTime != null)
                            Text(
                                'Salida: ${DateFormat('HH:mm').format(checkOutTime)}'),
                          Text(
                              'Estado: ${attendance['status'] ?? 'Desconocido'}'),
                        ],
                      ),
                      trailing: Icon(
                        checkOutTime != null
                            ? Icons.check_circle
                            : Icons.access_time,
                        color:
                            checkOutTime != null ? Colors.green : Colors.orange,
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
