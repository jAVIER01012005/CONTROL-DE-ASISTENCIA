part of 'attendance.dart';

AttendanceModel _$AttendanceModelFromJson(Map<String, dynamic> json) =>
    AttendanceModel(
      id: json['id'] as int?,
      userId: json['user_id'] as int,
      userName: json['user_name'] as String,
      checkInTime: DateTime.parse(json['check_in_time'] as String),
      checkOutTime: json['check_out_time'] == null
          ? null
          : DateTime.parse(json['check_out_time'] as String),
      checkInLatitude: (json['check_in_latitude'] as num).toDouble(),
      checkInLongitude: (json['check_in_longitude'] as num).toDouble(),
      checkOutLatitude: (json['check_out_latitude'] as num?)?.toDouble(),
      checkOutLongitude: (json['check_out_longitude'] as num?)?.toDouble(),
      status: json['status'] as String,
      notes: json['notes'] as String?,
      totalHours:
          AttendanceModel._durationFromSeconds(json['total_hours'] as int?),
    );

Map<String, dynamic> _$AttendanceModelToJson(AttendanceModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'user_name': instance.userName,
      'check_in_time': instance.checkInTime.toIso8601String(),
      'check_out_time': instance.checkOutTime?.toIso8601String(),
      'check_in_latitude': instance.checkInLatitude,
      'check_in_longitude': instance.checkInLongitude,
      'check_out_latitude': instance.checkOutLatitude,
      'check_out_longitude': instance.checkOutLongitude,
      'status': instance.status,
      'notes': instance.notes,
      'total_hours': AttendanceModel._durationToSeconds(instance.totalHours),
    };
