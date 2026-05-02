import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../domain/task_attachment.dart';

class TaskAttachmentStorage {
  TaskAttachmentStorage({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  Future<TaskAttachment> saveImageBytes({
    required String taskId,
    required Uint8List bytes,
    String fileName = 'pasted-image.png',
    String mimeType = 'image/png',
  }) async {
    final attachmentId = _uuid.v4();
    final storedFile = await _writeAttachmentFile(
      taskId: taskId,
      attachmentId: attachmentId,
      sourceBytes: bytes,
      originalFileName: fileName,
    );

    return TaskAttachment(
      id: attachmentId,
      kind: TaskAttachmentKind.image,
      displayName: fileName,
      mimeType: mimeType,
      localPath: storedFile.path,
      sizeBytes: bytes.lengthInBytes,
      createdAt: DateTime.now(),
    );
  }

  Future<TaskAttachment> saveFile({
    required String taskId,
    required File sourceFile,
    required String displayName,
    required String mimeType,
  }) async {
    final attachmentId = _uuid.v4();
    final storedFile = await _writeAttachmentFile(
      taskId: taskId,
      attachmentId: attachmentId,
      sourceBytes: await sourceFile.readAsBytes(),
      originalFileName: displayName,
    );

    return TaskAttachment(
      id: attachmentId,
      kind: _isImageMimeType(mimeType)
          ? TaskAttachmentKind.image
          : TaskAttachmentKind.file,
      displayName: displayName,
      mimeType: mimeType,
      localPath: storedFile.path,
      sizeBytes: await storedFile.length(),
      createdAt: DateTime.now(),
    );
  }

  Future<void> deleteAttachment(TaskAttachment attachment) async {
    final file = File(attachment.localPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<File> _writeAttachmentFile({
    required String taskId,
    required String attachmentId,
    required Uint8List sourceBytes,
    required String originalFileName,
  }) async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}task_attachments${Platform.pathSeparator}$taskId',
    );
    await directory.create(recursive: true);

    final extension = _fileExtension(originalFileName);
    final file = File(
      '${directory.path}${Platform.pathSeparator}$attachmentId$extension',
    );
    await file.writeAsBytes(sourceBytes, flush: true);
    return file;
  }

  bool _isImageMimeType(String mimeType) => mimeType.startsWith('image/');

  String _fileExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex < 0) {
      return '';
    }
    return fileName.substring(dotIndex);
  }
}
