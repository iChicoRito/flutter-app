enum TaskAttachmentKind { image, file }

class TaskAttachment {
  const TaskAttachment({
    required this.id,
    required this.kind,
    required this.displayName,
    required this.mimeType,
    required this.localPath,
    required this.sizeBytes,
    required this.createdAt,
  });

  final String id;
  final TaskAttachmentKind kind;
  final String displayName;
  final String mimeType;
  final String localPath;
  final int sizeBytes;
  final DateTime createdAt;

  TaskAttachment copyWith({
    String? id,
    TaskAttachmentKind? kind,
    String? displayName,
    String? mimeType,
    String? localPath,
    int? sizeBytes,
    DateTime? createdAt,
  }) {
    return TaskAttachment(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      displayName: displayName ?? this.displayName,
      mimeType: mimeType ?? this.mimeType,
      localPath: localPath ?? this.localPath,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
