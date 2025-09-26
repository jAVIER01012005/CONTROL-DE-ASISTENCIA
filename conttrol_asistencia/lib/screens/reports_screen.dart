import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/http_services.dart';
import '../utils/app_theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final HttpService _httpService = HttpService();
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  List<dynamic> _reportData = [];
  bool _isLoading = false;
  String? _selectedUserId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Filtrar reportes
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filtrar Reporte',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),

                    // Rango de fechas
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _selectDate(true),
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                                DateFormat('dd/MM/yyyy').format(_startDate)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('a'),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _selectDate(false),
                            icon: const Icon(Icons.calendar_today),
                            label:
                                Text(DateFormat('dd/MM/yyyy').format(_endDate)),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Boton de generar reporte
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _generateReport,
                            icon: const Icon(Icons.search),
                            label: const Text('Generar Reporte'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _exportToExcel,
                            icon: const Icon(Icons.table_chart),
                            label: const Text('Exportar Excel'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.successColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Resultados
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_reportData.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resultados (${_reportData.length} registros)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ..._reportData.map((attendance) {
                    // Crear un Card personalizado para mostrar la información
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
                            attendance['user_name'] ?? 'Usuario desconocido'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (checkInTime != null)
                              Text(
                                  'Entrada: ${DateFormat('dd/MM/yyyy HH:mm').format(checkInTime)}'),
                            if (checkOutTime != null)
                              Text(
                                  'Salida: ${DateFormat('dd/MM/yyyy HH:mm').format(checkOutTime)}'),
                            Text(
                                'Estado: ${attendance['status'] ?? 'Desconocido'}'),
                            if (attendance['total_hours'] != null)
                              Text('Horas: ${attendance['total_hours']}h'),
                          ],
                        ),
                        trailing: Icon(
                          checkOutTime != null
                              ? Icons.check_circle
                              : Icons.access_time,
                          color: checkOutTime != null
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                    );
                  }),
                ],
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(Icons.analytics, size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      const Text('No hay datos para mostrar'),
                      const SizedBox(height: 8),
                      const Text(
                          'Selecciona un rango de fechas y genera un reporte'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _generateReport() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _reportData = [];
    });

    try {
      final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);

      // Construir la URL con los parámetros
      String url =
          '/attendance/date-range?start_date=$startDateStr&end_date=$endDateStr';
      if (_selectedUserId != null) {
        url += '&user_id=$_selectedUserId';
      }

      final response = await _httpService.get(url);

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final attendances = data['attendances'] ?? [];

        if (mounted) {
          setState(() {
            _reportData = List<dynamic>.from(attendances);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error generando reporte')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generando reporte: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _exportToExcel() async {
    if (_reportData.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay datos para exportar')),
        );
      }
      return;
    }

    try {
      final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);

      final response = await _httpService.post('/reports/generate', data: {
        'start_date': startDateStr,
        'end_date': endDateStr,
        'user_id': _selectedUserId,
        'format': 'excel',
      });

      if (mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reporte exportado exitosamente')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al exportar reporte')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error de conexión')),
        );
      }
    }
  }
}
