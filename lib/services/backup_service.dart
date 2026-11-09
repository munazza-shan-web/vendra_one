import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../data/local/database/app_database.dart';

class BackupService {
  const BackupService(this.database);

  final AppDatabase database;

  Future<bool> createBackup() async {
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/vendra_one_backup_${DateTime.now().millisecondsSinceEpoch}.sqlite',
    );

    try {
      await database.createBackup(file.path);
      final bytes = await file.readAsBytes();
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save VendraOne backup',
        fileName: 'vendra_one_backup.sqlite',
        type: FileType.custom,
        allowedExtensions: const ['sqlite'],
        bytes: bytes,
      );
      return savedPath != null;
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  Future<bool> restoreBackup() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select a VendraOne backup',
      type: FileType.custom,
      allowedExtensions: const ['sqlite', 'db'],
      withData: true,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return false;
    final bytes = result.files.single.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw const FormatException('Could not read the selected backup file.');
    }

    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/vendra_one_restore_${DateTime.now().millisecondsSinceEpoch}.sqlite',
    );

    try {
      await file.writeAsBytes(bytes, flush: true);
      await database.restoreBackup(file.path);
      return true;
    } finally {
      if (await file.exists()) await file.delete();
    }
  }
}
