import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../models/library_event_row.dart';
import '../models/shelf_row.dart';

/// Status eines Exemplars.
abstract class CopyStatus {
  static const inShelf = 'inShelf';
  static const removed = 'removed';
  static const lent = 'lent';
}

abstract class ShelfFilter {
  static const all = 'all';
  static const inShelf = CopyStatus.inShelf;
  static const removed = CopyStatus.removed;
  static const lent = CopyStatus.lent;
}

class BookDetail {
  const BookDetail({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.isbn13,
    this.isbn10,
    this.subtitle,
    this.authorsText,
    this.publisher,
    this.publishedYear,
    this.language,
    this.coverUrl,
    required this.metadataManual,
  });

  final String id;
  final String? isbn13;
  final String? isbn10;
  final String title;
  final String? subtitle;
  final String? authorsText;
  final String? publisher;
  final String? publishedYear;
  final String? language;
  final String? coverUrl;
  final bool metadataManual;
  final int createdAt;
  final int updatedAt;
}

class CopyDetail {
  const CopyDetail({
    required this.id,
    required this.bookId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.locationId,
    this.conditionText,
    this.notes,
    this.acquiredAt,
    this.removedAt,
    this.removeReason,
  });

  final String id;
  final String bookId;
  final String? locationId;
  final String? conditionText;
  final String status;
  final String? notes;
  final int? acquiredAt;
  final int? removedAt;
  final String? removeReason;
  final int createdAt;
  final int updatedAt;
}

class LocationRow {
  const LocationRow({
    required this.id,
    required this.name,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final int sortOrder;

  static LocationRow fromMap(Map<String, Object?> m) {
    return LocationRow(
      id: m['id']! as String,
      name: m['name']! as String,
      sortOrder: m['sort_order']! as int,
    );
  }
}

class LibraryRepository {
  LibraryRepository(this._db);

  final AppDatabase _db;

  /// Standard-Standort aus Seed-Daten ([_ensureSeed]).
  static const defaultLocationId = 'loc-default';
  static const metadataSourceOpenLibrary = 'open_library';
  static const metadataSourceGoogleBooks = 'google_books';
  static const metadataSourceDnb = 'dnb';
  static const _uuid = Uuid();

  Future<String?> getMetadataCache(String isbn13, String source) async {
    final row = await (_db.select(_db.metadataCaches)
          ..where((t) => t.isbn13.equals(isbn13) & t.source.equals(source)))
        .getSingleOrNull();
    return row?.payloadJson;
  }

  Future<void> putMetadataCache({
    required String isbn13,
    required String source,
    required String payloadJson,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.into(_db.metadataCaches).insert(
          MetadataCachesCompanion.insert(
            isbn13: isbn13,
            source: source,
            payloadJson: payloadJson,
            fetchedAt: now,
          ),
          mode: InsertMode.replace,
        );
  }

  Future<void> _ensureSeed() async {
    final existing = await _db.select(_db.locations).get();
    if (existing.isEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.into(_db.locations).insert(
            LocationsCompanion.insert(
              id: defaultLocationId,
              name: 'Ohne Regal',
              sortOrder: const Value(0),
            ),
          );
      await _insertEvent(
        copyId: null,
        bookId: null,
        type: 'seed',
        detail: 'default_location',
        at: now,
      );
    }
  }

  Future<void> ensureInitialized() => _ensureSeed();

  Future<void> _insertEvent({
    required String? copyId,
    required String? bookId,
    required String type,
    required String? detail,
    required int at,
  }) async {
    await _db.into(_db.libraryEvents).insert(
          LibraryEventsCompanion.insert(
            id: _uuid.v4(),
            copyId: Value(copyId),
            bookId: Value(bookId),
            type: type,
            detail: Value(detail),
            createdAt: at,
          ),
        );
  }

  Future<List<ShelfRow>> queryShelf({
    required String filter,
    required String search,
  }) async {
    final vars = <Variable<Object>>[];
    final clauses = <String>[];

    if (filter != ShelfFilter.all) {
      clauses.add('c.status = ?');
      vars.add(Variable<String>(filter));
    }

    if (search.trim().isNotEmpty) {
      final q = '%${search.trim()}%';
      clauses.add('''
(b.title LIKE ? OR IFNULL(b.authors_text,'') LIKE ? OR IFNULL(b.isbn13,'') LIKE ? OR IFNULL(b.isbn10,'') LIKE ?)
''');
      vars.addAll([
        Variable<String>(q),
        Variable<String>(q),
        Variable<String>(q),
        Variable<String>(q),
      ]);
    }

    final where = clauses.isEmpty ? '1=1' : clauses.join(' AND ');

    final rows = await _db.customSelect(
      '''
SELECT
  c.id AS copy_id,
  c.book_id AS book_id,
  c.status AS status,
  c.condition_text AS condition_text,
  c.notes AS notes,
  c.updated_at AS updated_at,
  b.title AS title,
  b.subtitle AS subtitle,
  b.authors_text AS authors_text,
  b.isbn13 AS isbn13,
  b.isbn10 AS isbn10,
  l.name AS location_name
FROM copies c
INNER JOIN books b ON b.id = c.book_id
LEFT JOIN locations l ON l.id = c.location_id
WHERE $where
ORDER BY c.updated_at DESC
''',
      variables: vars,
    ).get();

    return rows
        .map(
          (row) => ShelfRow.fromMap({
            'copy_id': row.read<String>('copy_id'),
            'book_id': row.read<String>('book_id'),
            'status': row.read<String>('status'),
            'condition_text': row.readNullable<String>('condition_text'),
            'notes': row.readNullable<String>('notes'),
            'updated_at': row.read<int>('updated_at'),
            'title': row.read<String>('title'),
            'subtitle': row.readNullable<String>('subtitle'),
            'authors_text': row.readNullable<String>('authors_text'),
            'isbn13': row.readNullable<String>('isbn13'),
            'isbn10': row.readNullable<String>('isbn10'),
            'location_name': row.readNullable<String>('location_name'),
          }),
        )
        .toList();
  }

  BookDetail _bookToDetail(Book row) {
    return BookDetail(
      id: row.id,
      isbn13: row.isbn13,
      isbn10: row.isbn10,
      title: row.title,
      subtitle: row.subtitle,
      authorsText: row.authorsText,
      publisher: row.publisher,
      publishedYear: row.publishedYear,
      language: row.language,
      coverUrl: row.coverUrl,
      metadataManual: row.metadataManual,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  CopyDetail _copyToDetail(Copy row) {
    return CopyDetail(
      id: row.id,
      bookId: row.bookId,
      locationId: row.locationId,
      conditionText: row.conditionText,
      status: row.status,
      notes: row.notes,
      acquiredAt: row.acquiredAt,
      removedAt: row.removedAt,
      removeReason: row.removeReason,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  Future<BookDetail?> getBook(String id) async {
    final row = await (_db.select(_db.books)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _bookToDetail(row);
  }

  Future<CopyDetail?> getCopy(String id) async {
    final row = await (_db.select(_db.copies)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _copyToDetail(row);
  }

  /// Alle „Im Regal“-Exemplare zu einer ISBN-13 (Duplikat-Auswahl).
  Future<List<CopyDetail>> copiesInShelfForIsbn13(String isbn13) async {
    final rows = await _db.customSelect(
      '''
SELECT c.* FROM copies c
INNER JOIN books b ON b.id = c.book_id
WHERE b.isbn13 = ? AND c.status = ?
ORDER BY c.updated_at DESC
''',
      variables: [
        Variable<String>(isbn13),
        Variable<String>(CopyStatus.inShelf),
      ],
    ).get();
    return rows.map((r) {
      return CopyDetail(
        id: r.read<String>('id'),
        bookId: r.read<String>('book_id'),
        locationId: r.readNullable<String>('location_id'),
        conditionText: r.readNullable<String>('condition_text'),
        status: r.read<String>('status'),
        notes: r.readNullable<String>('notes'),
        acquiredAt: r.readNullable<int>('acquired_at'),
        removedAt: r.readNullable<int>('removed_at'),
        removeReason: r.readNullable<String>('remove_reason'),
        createdAt: r.read<int>('created_at'),
        updatedAt: r.read<int>('updated_at'),
      );
    }).toList();
  }

  Future<List<LibraryEventRow>> eventsForCopy(String copyId) async {
    final maps = await (_db.select(_db.libraryEvents)
          ..where((t) => t.copyId.equals(copyId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return maps
        .map(
          (e) => LibraryEventRow.fromMap({
            'id': e.id,
            'type': e.type,
            'detail': e.detail,
            'created_at': e.createdAt,
          }),
        )
        .toList();
  }

  Future<List<LocationRow>> listLocations() async {
    final maps = await (_db.select(_db.locations)
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .get();
    return maps
        .map(
          (l) => LocationRow(
            id: l.id,
            name: l.name,
            sortOrder: l.sortOrder,
          ),
        )
        .toList();
  }

  Future<String> addLocation(String name) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxRow = await _db.customSelect(
      'SELECT COALESCE(MAX(sort_order), -1) AS m FROM locations',
    ).getSingle();
    final next = (maxRow.read<int?>('m') ?? -1) + 1;
    await _db.into(_db.locations).insert(
          LocationsCompanion.insert(
            id: id,
            name: name.trim(),
            sortOrder: Value(next),
          ),
        );
    await _insertEvent(
      copyId: null,
      bookId: null,
      type: 'location_add',
      detail: name.trim(),
      at: now,
    );
    return id;
  }

  Future<String> addManualCopy({
    required String title,
    String? subtitle,
    String? authorsText,
    String? isbn13,
    String? isbn10,
    String? publisher,
    String? publishedYear,
    String? language,
    String? locationId,
    String? conditionText,
    String? notes,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final bookId = _uuid.v4();
    final copyId = _uuid.v4();

    await _db.transaction(() async {
      await _db.into(_db.books).insert(
            BooksCompanion.insert(
              id: bookId,
              title: title.trim(),
              isbn13: Value(isbn13),
              isbn10: Value(isbn10),
              subtitle: Value(subtitle?.trim()),
              authorsText: Value(authorsText?.trim()),
              publisher: Value(publisher?.trim()),
              publishedYear: Value(publishedYear?.trim()),
              language: Value(language?.trim()),
              coverUrl: const Value.absent(),
              metadataManual: const Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await _db.into(_db.copies).insert(
            CopiesCompanion.insert(
              id: copyId,
              bookId: bookId,
              locationId: Value(locationId ?? defaultLocationId),
              conditionText: Value(conditionText?.trim()),
              status: CopyStatus.inShelf,
              notes: Value(notes?.trim()),
              acquiredAt: Value(now),
              removedAt: const Value.absent(),
              removeReason: const Value.absent(),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await _insertEvent(
        copyId: copyId,
        bookId: bookId,
        type: 'acquire',
        detail: 'manual',
        at: now,
      );
    });

    return copyId;
  }

  Future<BookDetail?> findBookByIsbn({String? isbn13, String? isbn10}) async {
    if (isbn13 != null) {
      final r = await (_db.select(_db.books)
            ..where((t) => t.isbn13.equals(isbn13))
            ..limit(1))
          .getSingleOrNull();
      if (r != null) return _bookToDetail(r);
    }
    if (isbn10 != null) {
      final r = await (_db.select(_db.books)
            ..where((t) => t.isbn10.equals(isbn10))
            ..limit(1))
          .getSingleOrNull();
      if (r != null) return _bookToDetail(r);
    }
    return null;
  }

  Future<String> addCopyForIsbn({
    required String isbn13,
    String? isbn10,
    String? prefilledTitle,
    String? subtitle,
    String? authorsText,
    String? publisher,
    String? publishedYear,
    String? language,
    String? coverUrl,
    bool metadataManual = false,
    String? locationId,
    String? conditionText,
    String? notes,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await findBookByIsbn(isbn13: isbn13, isbn10: isbn10);
    final copyId = _uuid.v4();

    await _db.transaction(() async {
      late final String bookId;
      if (existing != null) {
        bookId = existing.id;
        final allowMerge = !existing.metadataManual && !metadataManual;
        if (allowMerge) {
          final hasTitle =
              prefilledTitle != null && prefilledTitle.trim().isNotEmpty;
          final hasSubtitle = subtitle != null && subtitle.trim().isNotEmpty;
          final hasAuthors =
              authorsText != null && authorsText.trim().isNotEmpty;
          final hasPublisher =
              publisher != null && publisher.trim().isNotEmpty;
          final hasYear =
              publishedYear != null && publishedYear.trim().isNotEmpty;
          final hasLanguage = language != null && language.trim().isNotEmpty;
          final hasCover = coverUrl != null && coverUrl.trim().isNotEmpty;
          if (hasTitle ||
              hasSubtitle ||
              hasAuthors ||
              hasPublisher ||
              hasYear ||
              hasLanguage ||
              hasCover) {
            await (_db.update(_db.books)..where((t) => t.id.equals(bookId)))
                .write(
              BooksCompanion(
                updatedAt: Value(now),
                title: hasTitle
                    ? Value(prefilledTitle.trim())
                    : const Value.absent(),
                subtitle: hasSubtitle ? Value(subtitle.trim()) : const Value.absent(),
                authorsText:
                    hasAuthors ? Value(authorsText.trim()) : const Value.absent(),
                publisher:
                    hasPublisher ? Value(publisher.trim()) : const Value.absent(),
                publishedYear: hasYear
                    ? Value(publishedYear.trim())
                    : const Value.absent(),
                language:
                    hasLanguage ? Value(language.trim()) : const Value.absent(),
                coverUrl:
                    hasCover ? Value(coverUrl.trim()) : const Value.absent(),
              ),
            );
          }
        }
      } else {
        bookId = _uuid.v4();
        final title = (prefilledTitle?.trim().isNotEmpty ?? false)
            ? prefilledTitle!.trim()
            : 'ISBN $isbn13';
        await _db.into(_db.books).insert(
              BooksCompanion.insert(
                id: bookId,
                title: title,
                isbn13: Value(isbn13),
                isbn10: Value(isbn10),
                subtitle: Value(subtitle),
                authorsText: Value(authorsText),
                publisher: Value(publisher),
                publishedYear: Value(publishedYear),
                language: Value(language),
                coverUrl: Value(coverUrl),
                metadataManual: Value(metadataManual),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }

      await _db.into(_db.copies).insert(
            CopiesCompanion.insert(
              id: copyId,
              bookId: bookId,
              locationId: Value(locationId ?? defaultLocationId),
              conditionText: Value(conditionText?.trim()),
              status: CopyStatus.inShelf,
              notes: Value(notes?.trim()),
              acquiredAt: Value(now),
              removedAt: const Value.absent(),
              removeReason: const Value.absent(),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await _insertEvent(
        copyId: copyId,
        bookId: bookId,
        type: 'acquire',
        detail: 'isbn',
        at: now,
      );
    });

    return copyId;
  }

  Future<void> updateBookMetadata({
    required String bookId,
    required String title,
    String? subtitle,
    String? authorsText,
    String? publisher,
    String? publishedYear,
    String? language,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.books)..where((t) => t.id.equals(bookId))).write(
          BooksCompanion(
            title: Value(title.trim()),
            subtitle: Value(subtitle?.trim()),
            authorsText: Value(authorsText?.trim()),
            publisher: Value(publisher?.trim()),
            publishedYear: Value(publishedYear?.trim()),
            language: Value(language?.trim()),
            metadataManual: const Value(true),
            updatedAt: Value(now),
          ),
        );
    await _insertEvent(
      copyId: null,
      bookId: bookId,
      type: 'edit_metadata',
      detail: null,
      at: now,
    );
  }

  Future<void> moveCopy({
    required String copyId,
    required String? locationId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final copy = await getCopy(copyId);
    if (copy == null) return;
    await (_db.update(_db.copies)..where((t) => t.id.equals(copyId))).write(
          CopiesCompanion(
            locationId: Value(locationId ?? defaultLocationId),
            updatedAt: Value(now),
          ),
        );
    await _insertEvent(
      copyId: copyId,
      bookId: copy.bookId,
      type: 'move',
      detail: locationId,
      at: now,
    );
  }

  Future<void> updateCopyNotes({
    required String copyId,
    String? conditionText,
    String? notes,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final copy = await getCopy(copyId);
    if (copy == null) return;
    await (_db.update(_db.copies)..where((t) => t.id.equals(copyId))).write(
          CopiesCompanion(
            conditionText: Value(conditionText?.trim()),
            notes: Value(notes?.trim()),
            updatedAt: Value(now),
          ),
        );
    await _insertEvent(
      copyId: copyId,
      bookId: copy.bookId,
      type: 'edit_copy',
      detail: null,
      at: now,
    );
  }

  Future<void> removeCopy({
    required String copyId,
    required String reason,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final copy = await getCopy(copyId);
    if (copy == null) return;
    await (_db.update(_db.copies)..where((t) => t.id.equals(copyId))).write(
          CopiesCompanion(
            status: Value(CopyStatus.removed),
            removedAt: Value(now),
            removeReason: Value(reason.trim()),
            updatedAt: Value(now),
          ),
        );
    await _insertEvent(
      copyId: copyId,
      bookId: copy.bookId,
      type: 'remove',
      detail: reason.trim(),
      at: now,
    );
  }

  Future<void> setLent(String copyId, {required bool lent}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final copy = await getCopy(copyId);
    if (copy == null) return;
    if (copy.status == CopyStatus.removed) return;
    final status = lent ? CopyStatus.lent : CopyStatus.inShelf;
    await (_db.update(_db.copies)..where((t) => t.id.equals(copyId))).write(
          CopiesCompanion(
            status: Value(status),
            updatedAt: Value(now),
          ),
        );
    await _insertEvent(
      copyId: copyId,
      bookId: copy.bookId,
      type: lent ? 'lend' : 'return',
      detail: null,
      at: now,
    );
  }
}
