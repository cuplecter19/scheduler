class TimeBlock {
  const TimeBlock({
    required this.id,
    required this.title,
    required this.startAt,
    required this.endAt,
    required this.colorHex,
    required this.updatedAt,
    this.taskId,
    this.note = '',
    this.isDeleted = false,
    this.deviceId = '',
  });

  final String id;
  final String title;
  final String? taskId;
  final String note;
  final DateTime startAt;
  final DateTime endAt;
  final String colorHex;
  final bool isDeleted;
  final DateTime updatedAt;
  final String deviceId;

  TimeBlock copyWith({
    String? id,
    String? title,
    String? taskId,
    bool clearTask = false,
    String? note,
    DateTime? startAt,
    DateTime? endAt,
    String? colorHex,
    bool? isDeleted,
    DateTime? updatedAt,
    String? deviceId,
  }) {
    return TimeBlock(
      id: id ?? this.id,
      title: title ?? this.title,
      taskId: clearTask ? null : taskId ?? this.taskId,
      note: note ?? this.note,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      colorHex: colorHex ?? this.colorHex,
      isDeleted: isDeleted ?? this.isDeleted,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'title': title,
        'task_id': taskId,
        'note': note,
        'start_at': startAt.toUtc().toIso8601String(),
        'end_at': endAt.toUtc().toIso8601String(),
        'color_hex': colorHex,
        'is_deleted': isDeleted ? 1 : 0,
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'device_id': deviceId,
      };

  factory TimeBlock.fromMap(Map<String, Object?> map) {
    return TimeBlock(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      taskId: map['task_id'] as String?,
      note: map['note'] as String? ?? '',
      startAt: DateTime.parse(map['start_at'] as String).toLocal(),
      endAt: DateTime.parse(map['end_at'] as String).toLocal(),
      colorHex: map['color_hex'] as String? ?? '#2D7FF9',
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
      updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
      deviceId: map['device_id'] as String? ?? '',
    );
  }

  Map<String, Object?> toSyncJson() => <String, Object?>{
        'id': id,
        'type': 'time_block',
        'data': toMap(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'is_deleted': isDeleted,
        'device_id': deviceId,
      };
}
