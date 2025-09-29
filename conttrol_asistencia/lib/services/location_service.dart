import 'package:conttrol_asistencia/services/http_services.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class LocationService with ChangeNotifier {
  final HttpService _httpService = HttpService();

  // Estado actual
  Position? _currentPosition;
  bool _isLocationServiceEnabled = false;
  String _currentAddress = '';
  bool _isWithinGeofence = false;
  bool _isLoading = false;
  String? _lastError;

  // Configuración de geofence
  double _officeLatitude = 15.7634; //15.772575
  double _officeLongitude = -86.75342; //86.793401
  double _geofenceRadius = 100.0;

  // Configuraciones adicionales
  double _accuracyThreshold = 50.0;
  Duration _locationTimeout = Duration(seconds: 10);
  Timer? _locationUpdateTimer;

  // Cache para direcciones
  final Map<String, String> _addressCache = {};

  // Getters
  Position? get currentPosition => _currentPosition;
  bool get isLocationServiceEnabled => _isLocationServiceEnabled;
  String get currentAddress => _currentAddress;
  bool get isWithinGeofence => _isWithinGeofence;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  double get officeLatitude => _officeLatitude;
  double get officeLongitude => _officeLongitude;
  double get geofenceRadius => _geofenceRadius;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _lastError = error;
    if (error != null) {
      debugPrint('Location Service Error: $error');
    }
    notifyListeners();
  }

  Future<LocationInitResult> initializeLocationService() async {
    _setLoading(true);
    _setError(null);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _isLocationServiceEnabled = false;
        _setError('Servicio de ubicación deshabilitado');
        return LocationInitResult.error(
            'El servicio de ubicación está deshabilitado.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _isLocationServiceEnabled = false;
          _setError('Permisos de ubicación denegados');
          return LocationInitResult.error('Permisos de ubicación denegados.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _isLocationServiceEnabled = false;
        _setError('Permisos de ubicación denegados permanentemente');
        return LocationInitResult.error('Permisos denegados permanentemente.');
      }

      _isLocationServiceEnabled = true;
      await loadOfficeLocation();
      await getCurrentPosition();
      _startLocationUpdates();

      return LocationInitResult.success('Servicio de ubicación inicializado');
    } catch (e) {
      _isLocationServiceEnabled = false;
      final errorMsg = 'Error inicializando ubicación: ${e.toString()}';
      _setError(errorMsg);
      return LocationInitResult.error(errorMsg);
    } finally {
      _setLoading(false);
    }
  }

  Future<Position?> getCurrentPosition({bool highAccuracy = true}) async {
    if (!_isLocationServiceEnabled) {
      final initResult = await initializeLocationService();
      if (!initResult.success) {
        return null;
      }
    }

    _setLoading(true);
    _setError(null);

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy:
            highAccuracy ? LocationAccuracy.high : LocationAccuracy.medium,
      ).timeout(_locationTimeout);

      if (position.accuracy > _accuracyThreshold) {
        _setError(
            'Precisión GPS insuficiente (${position.accuracy.round()}m).');
      }

      _currentPosition = position;
      await _updateCurrentAddress();
      _checkGeofence();
      _setError(null);
      return _currentPosition;
    } on TimeoutException {
      final errorMsg = 'Tiempo de espera agotado obteniendo ubicación';
      _setError(errorMsg);
      return null;
    } catch (e) {
      final errorMsg = 'Error obteniendo ubicación: ${e.toString()}';
      _setError(errorMsg);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _updateCurrentAddress() async {
    if (_currentPosition == null) return;

    try {
      final key =
          '${_currentPosition!.latitude.toStringAsFixed(4)},${_currentPosition!.longitude.toStringAsFixed(4)}';

      if (_addressCache.containsKey(key)) {
        _currentAddress = _addressCache[key]!;
        return;
      }

      List<Placemark> placemarks = await placemarkFromCoordinates(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      ).timeout(Duration(seconds: 10));

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        _currentAddress = _formatAddress(place);
        _addressCache[key] = _currentAddress;

        if (_addressCache.length > 50) {
          _addressCache.remove(_addressCache.keys.first);
        }
      }
    } catch (e) {
      _currentAddress = 'Dirección no disponible';
    }
  }

  String _formatAddress(Placemark place) {
    List<String> addressParts = [];
    if (place.street != null && place.street!.isNotEmpty)
      addressParts.add(place.street!);
    if (place.locality != null && place.locality!.isNotEmpty)
      addressParts.add(place.locality!);
    if (place.administrativeArea != null &&
        place.administrativeArea!.isNotEmpty)
      addressParts.add(place.administrativeArea!);
    return addressParts.isNotEmpty
        ? addressParts.join(', ')
        : 'Dirección no disponible';
  }

  void _checkGeofence() {
    if (_currentPosition == null) {
      _isWithinGeofence = false;
      return;
    }

    double distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _officeLatitude,
      _officeLongitude,
    );

    double effectiveRadius = _geofenceRadius;
    if (_currentPosition!.accuracy > 0) {
      effectiveRadius += _currentPosition!.accuracy;
    }

    _isWithinGeofence = distance <= effectiveRadius;
  }

  Future<void> loadOfficeLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _officeLatitude = prefs.getDouble('office_latitude') ?? _officeLatitude;
      _officeLongitude =
          prefs.getDouble('office_longitude') ?? _officeLongitude;
      _geofenceRadius = prefs.getDouble('geofence_radius') ?? _geofenceRadius;
    } catch (e) {
      debugPrint('Error cargando ubicación localmente: $e');
    }
  }

  Future<bool> saveOfficeLocation(
      double latitude, double longitude, double radius) async {
    try {
      if (latitude.abs() > 90 || longitude.abs() > 180) {
        _setError('Coordenadas inválidas');
        return false;
      }

      if (radius < 10 || radius > 1000) {
        _setError('El radio debe estar entre 10 y 1000 metros');
        return false;
      }

      // Guardar localmente
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('office_latitude', latitude);
      await prefs.setDouble('office_longitude', longitude);
      await prefs.setDouble('geofence_radius', radius);

      //  estado local actualizado
      _officeLatitude = latitude;
      _officeLongitude = longitude;
      _geofenceRadius = radius;

      // recálculo de geofence
      if (_currentPosition != null) {
        _checkGeofence();
      }

      notifyListeners();
      //   guardar en servidor
      try {
        final response =
            await _httpService.put('/settings/office-location', data: {
          'latitude': latitude,
          'longitude': longitude,
          'radius': radius,
        });

        if (response.statusCode != 200) {
          debugPrint('Error guardando en servidor, pero se guardó localmente');
        }
      } catch (e) {
        debugPrint('Error de conexión al guardar en servidor: $e');
      }

      return true;
    } catch (e) {
      _setError('Error guardando ubicación: ${e.toString()}');
      return false;
    }
  }

  double getDistanceToOffice() {
    if (_currentPosition == null) return double.infinity;
    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _officeLatitude,
      _officeLongitude,
    );
  }

  LocationStatus getDetailedLocationStatus() {
    if (!_isLocationServiceEnabled) {
      return LocationStatus(
        status: LocationStatusType.disabled,
        message: 'Ubicación deshabilitada',
        color: Colors.red,
        icon: Icons.location_disabled,
      );
    }

    if (_currentPosition == null) {
      return LocationStatus(
        status: LocationStatusType.loading,
        message: 'Obteniendo ubicación...',
        color: Colors.orange,
        icon: Icons.location_searching,
      );
    }

    if (_currentPosition!.accuracy > _accuracyThreshold) {
      return LocationStatus(
        status: LocationStatusType.lowAccuracy,
        message: 'Precisión baja (${_currentPosition!.accuracy.round()}m)',
        color: Colors.orange,
        icon: Icons.gps_not_fixed,
      );
    }

    if (_isWithinGeofence) {
      return LocationStatus(
        status: LocationStatusType.withinGeofence,
        message: 'En la oficina',
        color: Colors.green,
        icon: Icons.location_on,
      );
    } else {
      double distance = getDistanceToOffice();
      return LocationStatus(
        status: LocationStatusType.outsideGeofence,
        message: 'A ${distance.round()}m de la oficina',
        color: Colors.orange,
        icon: Icons.location_off,
      );
    }
  }

  void _startLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(Duration(minutes: 2), (timer) async {
      if (_isLocationServiceEnabled) {
        await getCurrentPosition(highAccuracy: false);
      }
    });
  }

  void stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
  }

  LocationValidation validateLocationForAttendance() {
    if (!_isLocationServiceEnabled) {
      return LocationValidation(
        isValid: false,
        reason: 'El servicio de ubicación está deshabilitado',
        suggestion: 'Habilita la ubicación en configuración',
      );
    }

    if (_currentPosition == null) {
      return LocationValidation(
        isValid: false,
        reason: 'No se pudo obtener tu ubicación actual',
        suggestion: 'Intenta actualizar tu ubicación',
      );
    }

    if (_currentPosition!.accuracy > _accuracyThreshold) {
      return LocationValidation(
        isValid: false,
        reason:
            'La precisión GPS es insuficiente (${_currentPosition!.accuracy.round()}m)',
        suggestion: 'Muévete a un lugar con mejor señal GPS',
      );
    }

    if (!_isWithinGeofence) {
      double distance = getDistanceToOffice();
      return LocationValidation(
        isValid: false,
        reason: 'Estás fuera del área permitida (${distance.round()}m)',
        suggestion:
            'Debes estar dentro de ${_geofenceRadius.round()}m de la oficina',
      );
    }

    return LocationValidation(
      isValid: true,
      reason: 'Ubicación válida para registro',
      suggestion: '',
    );
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    super.dispose();
  }
}

enum LocationStatusType {
  disabled,
  loading,
  withinGeofence,
  outsideGeofence,
  lowAccuracy,
  error
}

class LocationStatus {
  final LocationStatusType status;
  final String message;
  final Color color;
  final IconData icon;
  final double? distance;
  final double? accuracy;

  LocationStatus(
      {required this.status,
      required this.message,
      required this.color,
      required this.icon,
      this.distance,
      this.accuracy});
}

class LocationValidation {
  final bool isValid;
  final String reason;
  final String suggestion;

  LocationValidation(
      {required this.isValid, required this.reason, required this.suggestion});
}

class LocationInitResult {
  final bool success;
  final String message;

  LocationInitResult._({required this.success, required this.message});
  factory LocationInitResult.success(String message) =>
      LocationInitResult._(success: true, message: message);
  factory LocationInitResult.error(String message) =>
      LocationInitResult._(success: false, message: message);
}
