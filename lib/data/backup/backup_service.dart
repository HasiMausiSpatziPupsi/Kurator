import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restart_app/restart_app.dart';

import '../db/app_database.dart';
import '../../providers/providers.dart';

/// ZIP mit `bibliothek.db` + `manifest.json` (Schema, Zeitstempel, SHA-256).
class BackupService {
  BackupService._();

  static const manifestName = 'manifest.json';
  static const dbNameInZip = 'bibliothek.db';

  static Future<void> exportZip(WidgetRef ref) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Backup speichern',
      fileName: 'bibliothek_backup.zip',
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    if (path == null) return;

    final dbFile = await bibliothekDatabaseFile();
    if (!await dbFile.exists()) {
      throw StateError('Keine Datenbankdatei gefunden.');
    }
    final bytes = await dbFile.readAsBytes();
    final digest = sha256.convert(bytes);
    final manifest = jsonEncode(<String, dynamic>{
      'schemaVersion': 1,
      'exportTimestamp': DateTime.now().toUtc().toIso8601String(),
      'sha256': digest.toString(),
      'app': 'inventur_app_v1',
      'dbFileName': dbNameInZip,
    });
    final manifestBytes = utf8.encode(manifest);

    final archive = Archive()
      ..addFile(ArchiveFile(dbNameInZip, bytes.length, bytes))
      ..addFile(ArchiveFile(manifestName, manifestBytes.length, manifestBytes));

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw StateError('ZIP-Kodierung fehlgeschlagen.');
    }
    await File(path).writeAsBytes(zipBytes);
  }

  /// Ersetzt die lokale DB nach Bestätigung; App-Neustart zur sauberen Neuinitialisierung.
  static Future<void> importZipReplace(WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.single;
    final raw = f.bytes;
    if (raw == null) {
      throw StateError('Datei konnte nicht gelesen werden.');
    }

    final archive = ZipDecoder().decodeBytes(raw);
    final manifestEntry = archive.findFile(manifestName);
    final dbEntry = archive.findFile(dbNameInZip);
    if (manifestEntry == null || dbEntry == null) {
      throw StateError('Ungültiges Backup (manifest oder DB fehlt).');
    }

    final manifest =
        jsonDecode(utf8.decode(manifestEntry.content as List<int>))
            as Map<String, dynamic>;
    final expectedSha = manifest['sha256'] as String?;
    final dbBytes = dbEntry.content as List<int>;
    final actual = sha256.convert(dbBytes).toString();
    if (expectedSha != null && expectedSha != actual) {
      throw StateError('Prüfsumme stimmt nicht (Manifest $expectedSha / Datei $actual).');
    }

    ref.invalidate(libraryRepositoryProvider);
    ref.invalidate(appDatabaseProvider);
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final dest = await bibliothekDatabaseFile();
    await dest.writeAsBytes(dbBytes);

    Restart.restartApp();
  }
}
