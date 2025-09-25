import 'package:conttrol_asistencia/services/http_services.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';

class AuthService with ChangeNotifier {
  final HttpService _httpService = HttpService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _token;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get token => _token;
  String? get error => _error;

  // Inicializar usuario actual
  Future<void> initializeUser() async {
    _isLoading = true;
    notifyListeners();

    try {
      _token = await _httpService.getToken();

      if (_token != null) {
        await _loadUserProfile();
      }
    } catch (e) {
      _error = 'Error inicializando usuario: $e';
      print(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Cargar perfil del usuario
  Future<void> _loadUserProfile() async {
    try {
      final response = await _httpService.get('/auth/profile');

      if (response.statusCode == 200 && response.data != null) {
        _currentUser = UserModel.fromJson(response.data['user']);
        _error = null;
      } else {
        await signOut();
      }
    } catch (e) {
      _error = 'Error cargando perfil: $e';
      print(_error);
      await signOut();
    }
  }

  // Inicio sesión
  Future<AuthResult> signIn(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _httpService.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;

        _token = data['token'];
        await _httpService.saveToken(_token!);

        _currentUser = UserModel.fromJson(data['user']);
        _error = null;

        _isLoading = false;
        notifyListeners();
        return AuthResult.success();
      } else {
        final errorMsg = response.data?['error'] ?? 'Error desconocido';
        _error = errorMsg;
        _isLoading = false;
        notifyListeners();
        return AuthResult.error(errorMsg);
      }
    } catch (e) {
      _error = 'Error de conexión: $e';
      _isLoading = false;
      notifyListeners();
      return AuthResult.error(_error!);
    }
  }

  // Registro de nuevo usuario
  Future<AuthResult> signUp(
      String email, String password, String name, String role) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _httpService.post('/auth/register', data: {
        'email': email,
        'password': password,
        'name': name,
        'role': role,
      });

      if (response.statusCode == 201 && response.data != null) {
        final data = response.data as Map<String, dynamic>;

        _token = data['token'];
        await _httpService.saveToken(_token!);

        _currentUser = UserModel.fromJson(data['user']);
        _error = null;

        _isLoading = false;
        notifyListeners();
        return AuthResult.success();
      } else {
        final errorMsg =
            response.data?['error'] ?? 'Error al registrar usuario';
        _error = errorMsg;
        _isLoading = false;
        notifyListeners();
        return AuthResult.error(errorMsg);
      }
    } catch (e) {
      _error = 'Error de conexión: $e';
      _isLoading = false;
      notifyListeners();
      return AuthResult.error(_error!);
    }
  }

  // Cerrar sesión
  Future<void> signOut() async {
    try {
      await _httpService.post('/auth/logout');
    } catch (e) {
      print('Error logging out from server: $e');
    }

    await _httpService.clearToken();
    _currentUser = null;
    _token = null;
    _error = null;
    notifyListeners();
  }

  // Limpiar error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Verifica si el usuario está autenticado
  bool get isAuthenticated => _token != null && _currentUser != null;

  // Verifica si es administrador
  bool get isAdmin => _currentUser?.role == 'admin';
}

// manejo de autenticación
class AuthResult {
  final bool success;
  final String? errorMessage;

  AuthResult._({required this.success, this.errorMessage});

  factory AuthResult.success() => AuthResult._(success: true);
  factory AuthResult.error(String message) =>
      AuthResult._(success: false, errorMessage: message);
}
