enum TaskPriority { low, medium, high }

class ScheduledTask {
  const ScheduledTask({
    required this.id,
    required this.title,
    required this.updatedAt,
    this.note = '',
    this.dueDate,
    this.priority = TaskPriority.medium,
    this.tags = const <String>[],
    this.isCompleted = false,
    this.isDeleted = false,
    this.deviceId = '',
  });

  final String id;
  final String title;
  final String note;
  final DateTime? dueDate;
  final TaskPriority priority;
  final List<String> tags;
  final bool isCompleted;
  final bool isDeleted;
  final DateTime updatedAt;
  final String deviceId;

  ScheduledTask copyWith({
    String? id,
    String? title,
    String? note,
    DateTime? dueDate,
    bool clearDueDate = false,
    TaskPriority? priority,
    List<String>? tags,
    bool? isCompleted,
    bool? isDeleted,
    DateTime? updatedAt,
    String? deviceId,
  }) {
    return ScheduledTask(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      dueDate: clearDueDate ? null : dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      tags: tags ?? this.tags,
      isCompleted: isCompleted ?? this.isCompleted,
      isDeleted: isDeleted ?? this.isDeleted,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'title': title,
        'note': note,
        'due_date': dueDate?.toUtc().toIso8601String(),
        'priority': priority.name,
        'tags': tags.join(','),
        'is_completed': isCompleted ? 1 : 0,
        'is_deleted': isDeleted ? 1 : 0,
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'device_id': deviceId,
      };

  factory ScheduledTask.fromMap(Map<String, Object?> map) {
    return ScheduledTask(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      note: map['note'] as String? ?? '',
      dueDate: _date(map['due_date']),
      priority: TaskPriority.values.firstWhere(
        (value) => value.name == map['priority'],
        orElse: () => TaskPriority.medium,
      ),
      tags: (map['tags'] as String? ?? '')
          .split(',')
          .where((tag) => tag.trim().isNotEmpty)
          .map((tag) => tag.trim())
          .toList(),
      isCompleted: map['is_completed'] == 1 || map['is_completed'] == true,
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
      updatedAt: _date(map['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      deviceId: map['device_id'] as String? ?? '',
    );
  }

  Map<String, Object?> toSyncJson() => <String, Object?>{
        'id': id,
        'type': 'task',
        'data': toMap(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'is_deleted': isDeleted,
        'device_id': deviceId,
      };

  static DateTime? _date(Object? value) {
    if (value == null || value == '') return null;
    return DateTime.parse(value as String).toLocal();
  }
}
