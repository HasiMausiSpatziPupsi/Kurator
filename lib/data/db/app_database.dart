import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

part 'app_database.g.dart';

class Books extends Table {
  TextColumn get id => text()();
  TextColumn get isbn13 => text().nullable()();
  TextColumn get isbn10 => text().nullable()();
  TextColumn get title => text()();
  TextColumn get subtitle => text().nullable()();
  TextColumn get authorsText => text().nullable()();
  TextColumn get publisher => text().nullable()();
  TextColumn get publishedYear => text().nullable()();
  TextColumn get language => text().nullable()();
  TextColumn get coverUrl => text().nullable()();
  BoolColumn get metadataManual =>
      boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Locations extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Copies extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text().references(Books, #id)();
  TextColumn get locationId => text().nullable().references(Locations, #id)();
  TextColumn get conditionText => text().nullable()();
  TextColumn get status => text()();
  TextColumn get notes => text().nullable()();
  IntColumn get acquiredAt => integer().nullable()();
  IntColumn get removedAt => integer().nullable()();
  TextColumn get removeReason => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LibraryEvents extends Table {
  TextColumn get id => text()();
  TextColumn get copyId => text().nullable()();
  TextColumn get bookId => text().nullable()();
  TextColumn get type => text()();
  TextColumn get detail => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Lokaler Cache für Online-Metadaten (ISBN-13 + Quelle).
class MetadataCaches extends Table {
  TextColumn get isbn13 => text()();
  TextColumn get source => text()();
  TextColumn get payloadJson => text()();
  IntColumn get fetchedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {isbn13, source};
}

/// Einheitlicher Pfad zur SQLite-Datei (Backup/Import).
Future<File> bibliothekDatabaseFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File(p.join(dir.path, 'bibliothek.db'));
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }
    final file = await bibliothekDatabaseFile();
    return NativeDatabase.createInBackground(file);
  });
}

@DriftDatabase(
  tables: [Books, Locations, Copies, LibraryEvents, MetadataCaches],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}
