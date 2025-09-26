import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = Provider.of<AuthService>(context, listen: false);

    final result = await authService.signIn(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (result.success) {
      // Redirigir según el rol del usuario
      if (authService.isAdmin) {
        Navigator.of(context).pushReplacementNamed('/admin-home');
      } else {
        Navigator.of(context).pushReplacementNamed('/employee-home');
      }
    } else {
      setState(() {
        _errorMessage = result.errorMessage ?? 'Error desconocido';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 60),

              // Logo y título
              Icon(
                Icons.check_circle_outline,
                size: 100,
                color: AppTheme.primaryColor,
              ),
              SizedBox(height: 24),

              Text(
                'Control de Asistencia',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),

              Text(
                'Ingresa tus credenciales para continuar',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              SizedBox(height: 48),

              // Formulario de login
              Card(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Email
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Correo electrónico',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingresa tu correo';
                            }
                            // EXPRESIÓN REGULAR CORREGIDA:
                            if (!RegExp(
                                    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                                .hasMatch(value)) {
                              return 'Ingresa un correo válido';
                            }
                            return null;
                          },
                        ),

                        SizedBox(height: 16),

                        // Contraseña
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingresa tu contraseña';
                            }
                            if (value.length < 6) {
                              return 'La contraseña debe tener al menos 6 caracteres';
                            }
                            return null;
                          },
                        ),

                        SizedBox(height: 24),

                        // Mensaje de error
                        if (_errorMessage.isNotEmpty)
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _errorMessage,
                              style: TextStyle(
                                color: AppTheme.errorColor,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        if (_errorMessage.isNotEmpty) SizedBox(height: 16),

                        // Botón de login
                        Consumer<AuthService>(
                          builder: (context, authService, child) {
                            return SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed:
                                    authService.isLoading ? null : _signIn,
                                child: authService.isLoading
                                    ? CircularProgressIndicator(
                                        color: Colors.white)
                                    : Text(
                                        'Iniciar Sesión',
                                        style: TextStyle(fontSize: 16),
                                      ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(height: 32),
              // Información de prueba
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Usuarios de prueba:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Empleado: empleado@test.com / 123456\nAdmin: admin@test.com / 123456',
                      style: TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
