import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/db/app_database.dart';
import '../data/metadata/google_books_service.dart';
import '../data/metadata/metadata_aggregator.dart';
import '../data/metadata/open_library_service.dart';
import '../data/models/shelf_row.dart';
import '../data/repositories/library_repository.dart';
import '../data/settings/app_settings.dart';

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

final appSettingsProvider = FutureProvider<AppSettings>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return AppSettings(prefs);
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final libraryRepositoryProvider = FutureProvider<LibraryRepository>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final repo = LibraryRepository(db);
  await repo.ensureInitialized();
  return repo;
});

final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
    ),
  );
});

final openLibraryProvider = Provider<OpenLibraryService>((ref) {
  return OpenLibraryService(ref.watch(dioProvider));
});

final googleBooksProvider = Provider<GoogleBooksService>((ref) {
  return GoogleBooksService(ref.watch(dioProvider));
});

final metadataAggregatorProvider = Provider<MetadataAggregator>((ref) {
  return MetadataAggregator(
    openLibrary: ref.watch(openLibraryProvider),
    googleBooks: ref.watch(googleBooksProvider),
  );
});

/// Nach Änderungen am Bestand: hochzählen, um Listen neu zu laden.
final shelfRefreshProvider = StateProvider<int>((ref) => 0);

final shelfFilterProvider =
    StateProvider<String>((ref) => ShelfFilter.inShelf);

final shelfSearchProvider = StateProvider<String>((ref) => '');

/// Tablet Master‑Detail: gewähltes Exemplar (Copy-ID).
final shelfSelectedCopyProvider =
    StateProvider<String?>((ref) => null);

final shelfRowsProvider =
    FutureProvider.autoDispose<List<ShelfRow>>((ref) async {
  ref.watch(shelfRefreshProvider);
  final filter = ref.watch(shelfFilterProvider);
  final search = ref.watch(shelfSearchProvider);
  final repo = await ref.watch(libraryRepositoryProvider.future);
  return repo.queryShelf(filter: filter, search: search);
});
