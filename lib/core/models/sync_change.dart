class SyncChange {
  const SyncChange({
    required this.id,
    required this.type,
    required this.data,
    required this.updatedAt,
    required this.isDeleted,
    required this.deviceId,
  });

  final String id;
  final String type;
  final Map<String, Object?> data;
  final DateTime updatedAt;
  final bool isDeleted;
  final String deviceId;

  factory SyncChange.fromJson(Map<String, Object?> json) {
    return SyncChange(
      id: json['id'] as String,
      type: json['type'] as String,
      data: Map<String, Object?>.from(json['data'] as Map),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      isDeleted: json['is_deleted'] == true,
      deviceId: json['device_id'] as String? ?? '',
    );
  }
}
