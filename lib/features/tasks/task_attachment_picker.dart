import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_toast.dart';

enum _AttachmentPickAction { camera, file }

class PickedTaskAttachment {
  const PickedTaskAttachment({
    required this.path,
    required this.name,
    this.mimeType,
  });

  final String path;
  final String name;
  final String? mimeType;
}

/// On Android: bottom sheet — take photo or pick a file.
/// Elsewhere: system file picker only (camera UI is unreliable on Windows).
Future<PickedTaskAttachment?> pickTaskAttachment(BuildContext context) async {
  if (kIsWeb) return _pickFile();

  if (Platform.isAndroid) {
    final action = await _showAndroidSourceSheet(context);
    if (action == null || !context.mounted) return null;
    if (action == _AttachmentPickAction.camera) {
      return _pickCameraPhoto(context);
    }
    return _pickFile();
  }

  return _pickFile();
}

Future<_AttachmentPickAction?> _showAndroidSourceSheet(BuildContext context) {
  return showAppBottomSheet<_AttachmentPickAction>(
    context: context,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Файл / фото',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(LucideIcons.camera),
                title: const Text('Сделать фото'),
                onTap: () =>
                    Navigator.pop(ctx, _AttachmentPickAction.camera),
              ),
              ListTile(
                leading: const Icon(LucideIcons.paperclip),
                title: const Text('Выбрать файл или фото'),
                onTap: () => Navigator.pop(ctx, _AttachmentPickAction.file),
              ),
              ListTile(
                leading: const Icon(LucideIcons.x),
                title: const Text('Отмена'),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<bool> _ensureCameraPermission(BuildContext context) async {
  final status = await Permission.camera.request();
  if (status.isGranted || status.isLimited) return true;
  if (!context.mounted) return false;
  showAppToast(
    context,
    status.isPermanentlyDenied
        ? 'Разрешите доступ к камере в настройках устройства'
        : 'Нет доступа к камере',
  );
  return false;
}

Future<PickedTaskAttachment?> _pickCameraPhoto(BuildContext context) async {
  if (!await _ensureCameraPermission(context)) return null;
  if (!context.mounted) return null;

  try {
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return null;
    final path = file.path;
    final name = file.name.isNotEmpty
        ? file.name
        : path.split(Platform.pathSeparator).last;
    return PickedTaskAttachment(
      path: path,
      name: name,
      mimeType: 'image/jpeg',
    );
  } on PlatformException catch (e) {
    debugPrint('[Attachment] camera failed: ${e.code} ${e.message}');
    if (!context.mounted) return null;
    final msg = e.message?.toLowerCase() ?? '';
    final denied = e.code.contains('permission') ||
        e.code.contains('access') ||
        msg.contains('permission') ||
        msg.contains('denied');
    showAppToast(
      context,
      denied ? 'Нет доступа к камере' : 'Не удалось сделать фото',
    );
    return null;
  } catch (e) {
    debugPrint('[Attachment] camera error: $e');
    if (context.mounted) {
      showAppToast(context, 'Не удалось сделать фото');
    }
    return null;
  }
}

Future<PickedTaskAttachment?> _pickFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.any,
    withData: false,
  );
  final file = result?.files.single;
  if (file == null || file.path == null) return null;
  return PickedTaskAttachment(
    path: file.path!,
    name: file.name,
  );
}
