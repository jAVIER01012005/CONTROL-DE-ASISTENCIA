import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/http_services.dart';
import '../models/user_model.dart';
import '../utils/app_theme.dart';

class UserManagementScreen extends StatefulWidget {
  @override
  _UserManagementScreenState createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final HttpService _httpService = HttpService();
  List<UserModel> _users = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    print('🔄 Cargando usuarios...');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _httpService.get('/users');
      print('📊 Respuesta del servidor: ${response.statusCode}');
      print('📦 Datos: ${response.data}');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final List<dynamic> usersJson = data['users'] ?? [];

        setState(() {
          _users = usersJson.map((json) => UserModel.fromJson(json)).toList();
          _isLoading = false;
        });
        print('✅ Usuarios cargados: ${_users.length}');
      } else {
        setState(() {
          _errorMessage = 'Error al cargar usuarios: ${response.statusCode}';
          _isLoading = false;
        });
        print('❌ Error cargando usuarios');
      }
    } catch (e) {
      print('❌ Error de conexión: $e');
      setState(() {
        _errorMessage = 'Error de conexión: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _createUser() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    String selectedRole = 'employee';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Crear Usuario'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Nombre'),
              ),
              TextField(
                controller: emailController,
                decoration: InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(labelText: 'Contraseña'),
                obscureText: true,
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedRole,
                items: [
                  DropdownMenuItem(value: 'employee', child: Text('Empleado')),
                  DropdownMenuItem(
                      value: 'admin', child: Text('Administrador')),
                ],
                onChanged: (value) {
                  selectedRole = value!;
                },
                decoration: InputDecoration(labelText: 'Rol'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  emailController.text.isEmpty ||
                  passwordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Todos los campos son requeridos')),
                );
                return;
              }

              try {
                final response = await _httpService.post('/users', data: {
                  'name': nameController.text,
                  'email': emailController.text,
                  'password': passwordController.text,
                  'role': selectedRole,
                });

                if (response.statusCode == 201) {
                  Navigator.of(context).pop();
                  _loadUsers();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Usuario creado exitosamente')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al crear usuario')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error de conexión')),
                );
              }
            },
            child: Text('Crear'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleUserStatus(UserModel user) async {
    try {
      final response =
          await _httpService.put('/users/${user.id}/status', data: {
        'is_active': !user.isActive,
      });

      if (response.statusCode == 200) {
        _loadUsers();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Usuario ${user.isActive ? 'desactivado' : 'activado'} exitosamente'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cambiar estado')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gestión de Usuarios'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _createUser,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _users.isEmpty
                  ? Center(child: Text('No hay usuarios registrados'))
                  : ListView.builder(
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        return Card(
                          margin:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(user.name[0].toUpperCase()),
                            ),
                            title: Text(user.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user.email),
                                Text('Rol: ${user.role}'),
                                Text(
                                    'Estado: ${user.isActive ? 'Activo' : 'Inactivo'}'),
                                Text(
                                    'Creado: ${DateFormat('dd/MM/yyyy').format(user.createdAt)}'),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    user.isActive
                                        ? Icons.block
                                        : Icons.check_circle,
                                    color: user.isActive
                                        ? AppTheme.errorColor
                                        : AppTheme.successColor,
                                  ),
                                  onPressed: () => _toggleUserStatus(user),
                                  tooltip:
                                      user.isActive ? 'Desactivar' : 'Activar',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
