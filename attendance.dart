import 'package:json_annotation/json_annotation.dart';
part 'attendance.g.dart';

@JsonSerializable()
class AttendanceModel {
  final int? id;
  @JsonKey(name: 'user_id')
  final int userId;
  @JsonKey(name: 'user_name')
  final String userName;
  @JsonKey(name: 'check_in_time')
  final DateTime checkInTime;
  @JsonKey(name: 'check_out_time')
  final DateTime? checkOutTime;
  @JsonKey(name: 'check_in_latitude')
  final double checkInLatitude;
  @JsonKey(name: 'check_in_longitude')
  final double checkInLongitude;
  @JsonKey(name: 'check_out_latitude')
  final double? checkOutLatitude;
  @JsonKey(name: 'check_out_longitude')
  final double? checkOutLongitude;
  final String status;
  final String? notes;
  @JsonKey(
      name: 'total_hours',
      fromJson: _durationFromSeconds,
      toJson: _durationToSeconds)
  final Duration? totalHours;

  AttendanceModel({
    this.id,
    required this.userId,
    required this.userName,
    required this.checkInTime,
    this.checkOutTime,
    required this.checkInLatitude,
    required this.checkInLongitude,
    this.checkOutLatitude,
    this.checkOutLongitude,
    required this.status,
    this.notes,
    this.totalHours,
  });

  // Crear desde JSON
  factory AttendanceModel.fromJson(Map<String, dynamic> json) =>
      _$AttendanceModelFromJson(json);

  // Convertir a JSON
  Map<String, dynamic> toJson() => _$AttendanceModelToJson(this);

  // Helpers para convertir Duration
  static Duration? _durationFromSeconds(int? seconds) {
    return seconds != null ? Duration(seconds: seconds) : null;
  }

  static int? _durationToSeconds(Duration? duration) {
    return duration?.inSeconds;
  }

  AttendanceModel copyWith({
    int? id,
    int? userId,
    String? userName,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    double? checkInLatitude,
    double? checkInLongitude,
    double? checkOutLatitude,
    double? checkOutLongitude,
    String? status,
    String? notes,
    Duration? totalHours,
  }) {
    return AttendanceModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      checkInLatitude: checkInLatitude ?? this.checkInLatitude,
      checkInLongitude: checkInLongitude ?? this.checkInLongitude,
      checkOutLatitude: checkOutLatitude ?? this.checkOutLatitude,
      checkOutLongitude: checkOutLongitude ?? this.checkOutLongitude,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      totalHours: totalHours ?? this.totalHours,
    );
  }

  String get formattedTotalHours {
    if (totalHours == null) return '--';
    int hours = totalHours!.inHours;
    int minutes = totalHours!.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  // Verificar si está completo (tiene entrada y salida)
  bool get isComplete => checkOutTime != null;
}
