import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/http_services.dart';
import '../services/location_service.dart';
import 'user_management_screen.dart';
import 'reports_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  List<dynamic> _todayAttendances = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTodayAttendances();
  }

  Future<void> _loadTodayAttendances() async {
    setState(() {
      _isLoading = true;
    });

    final httpService = HttpService();

    try {
      final response = await httpService.get('/attendance/today');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final attendances = data['attendances'] ?? [];

        setState(() {
          _todayAttendances = List<dynamic>.from(attendances);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _todayAttendances = [];
        });
      }
    } catch (e) {
      debugPrint('Error cargando asistencias: $e');
      setState(() {
        _isLoading = false;
        _todayAttendances = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panel Administrativo'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.today), text: 'Hoy'),
              Tab(icon: Icon(Icons.people), text: 'Usuarios'),
              Tab(icon: Icon(Icons.analytics), text: 'Reportes'),
              Tab(icon: Icon(Icons.settings), text: 'Configuración'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadTodayAttendances,
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
        body: TabBarView(
          children: [
            _buildTodayTab(),
            UserManagementScreen(),
            ReportsScreen(),
            _buildSettingsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayTab() {
    return RefreshIndicator(
      onRefresh: _loadTodayAttendances,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Asistencias de Hoy',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('EEEE, dd MMMM yyyy', 'es_ES')
                          .format(DateTime.now()),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildStatsCard(),
            const SizedBox(height: 16),
            Text(
              'Registros del Día',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_todayAttendances.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(Icons.people_outline,
                          size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      const Text('No hay registros para hoy'),
                    ],
                  ),
                ),
              )
            else
              ..._todayAttendances.map((attendanceData) {
                final checkInTime = attendanceData['check_in_time'] != null
                    ? DateTime.parse(attendanceData['check_in_time'])
                    : null;
                final checkOutTime = attendanceData['check_out_time'] != null
                    ? DateTime.parse(attendanceData['check_out_time'])
                    : null;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    title: Text(
                        attendanceData['user_name'] ?? 'Usuario desconocido'),
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
                            'Estado: ${attendanceData['status'] ?? 'Desconocido'}'),
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
    );
  }

  Widget _buildStatsCard() {
    final presentCount = _todayAttendances.length;
    final completedCount = _todayAttendances
        .where((attendance) => attendance['check_out_time'] != null)
        .length;
    final pendingCount = presentCount - completedCount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estadísticas del Día',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                    'Presentes', presentCount.toString(), Colors.blue),
                _buildStatItem(
                    'Completados', completedCount.toString(), Colors.green),
                _buildStatItem(
                    'Pendientes', pendingCount.toString(), Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ubicación de la Empresa',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Configura la ubicación para el registro de asistencias',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showLocationSettingsDialog(context),
                    icon: const Icon(Icons.location_on),
                    label: const Text('Configurar Ubicación'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Horarios de Trabajo',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Configura los horarios de entrada y salida',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showWorkScheduleDialog(context),
                    icon: const Icon(Icons.schedule),
                    label: const Text('Configurar Horarios'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLocationSettingsDialog(BuildContext context) async {
    final locationService =
        Provider.of<LocationService>(context, listen: false);
    final TextEditingController latController = TextEditingController();
    final TextEditingController lngController = TextEditingController();
    final TextEditingController radiusController = TextEditingController();

    // Cargar ubicación actual
    await locationService.loadOfficeLocation();

    latController.text = locationService.officeLatitude.toString();
    lngController.text = locationService.officeLongitude.toString();
    radiusController.text = locationService.geofenceRadius.toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configurar Ubicación de Oficina'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: latController,
                decoration: const InputDecoration(
                    labelText: 'Latitud', hintText: 'Ej: 15.7634'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lngController,
                decoration: const InputDecoration(
                    labelText: 'Longitud', hintText: 'Ej: -86.75342'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: radiusController,
                decoration: const InputDecoration(
                    labelText: 'Radio (metros)', hintText: 'Ej: 100'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              const Text(
                'Nota: El radio define el área permitida para marcar asistencia',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final double? lat = double.tryParse(latController.text);
              final double? lng = double.tryParse(lngController.text);
              final double? radius = double.tryParse(radiusController.text);

              if (lat == null || lng == null || radius == null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Por favor ingresa valores válidos')),
                  );
                }
                return;
              }

              if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coordenadas inválidas')),
                  );
                }
                return;
              }

              if (radius < 10 || radius > 1000) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('El radio debe estar entre 10 y 1000 metros')),
                  );
                }
                return;
              }

              final success =
                  await locationService.saveOfficeLocation(lat, lng, radius);

              if (context.mounted) {
                if (success) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Ubicación actualizada correctamente')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Error al actualizar ubicación')),
                  );
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showWorkScheduleDialog(BuildContext context) {
    final TextEditingController startController =
        TextEditingController(text: '08:00');
    final TextEditingController endController =
        TextEditingController(text: '17:00');
    final TextEditingController toleranceController =
        TextEditingController(text: '15');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configurar Horarios de Trabajo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: startController,
                decoration: const InputDecoration(
                    labelText: 'Hora de entrada (HH:MM)',
                    hintText: 'Ej: 08:00'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: endController,
                decoration: const InputDecoration(
                    labelText: 'Hora de salida (HH:MM)', hintText: 'Ej: 17:00'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: toleranceController,
                decoration: const InputDecoration(
                    labelText: 'Tolerancia (minutos)', hintText: 'Ej: 15'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final httpService = HttpService();

              try {
                final response =
                    await httpService.put('/settings/work-schedule', data: {
                  'start_time': startController.text,
                  'end_time': endController.text,
                  'tolerance_minutes': int.parse(toleranceController.text),
                  'work_days': [1, 2, 3, 4, 5],
                });

                if (context.mounted) {
                  if (response.statusCode == 200) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Horarios actualizados correctamente')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Error al actualizar horarios')),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error de conexión')),
                  );
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
