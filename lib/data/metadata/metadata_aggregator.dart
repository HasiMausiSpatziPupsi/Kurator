import 'book_lookup_result.dart';
import 'google_books_service.dart';
import 'open_library_service.dart';
import '../repositories/library_repository.dart';

/// Reihenfolge: Cache (je Quelle) → Open Library → optional Google Books.
class MetadataAggregator {
  MetadataAggregator({
    required this.openLibrary,
    required this.googleBooks,
  });

  final OpenLibraryService openLibrary;
  final GoogleBooksService googleBooks;

  Future<BookLookupResult?> lookupIsbn13({
    required String isbn13,
    required LibraryRepository repository,
    required bool allowNetwork,
  }) async {
    final cachedOl =
        await repository.getMetadataCache(isbn13, LibraryRepository.metadataSourceOpenLibrary);
    if (cachedOl != null) {
      return BookLookupResult.fromJsonString(cachedOl);
    }
    final cachedGb =
        await repository.getMetadataCache(isbn13, LibraryRepository.metadataSourceGoogleBooks);
    if (cachedGb != null) {
      return BookLookupResult.fromJsonString(cachedGb);
    }

    if (!allowNetwork) return null;

    final ol = await openLibrary.lookupByIsbn(isbn13);
    if (ol != null) {
      await repository.putMetadataCache(
        isbn13: isbn13,
        source: LibraryRepository.metadataSourceOpenLibrary,
        payloadJson: ol.toJsonString(),
      );
      return ol;
    }

    if (googleBooks.isConfigured) {
      final gb = await googleBooks.lookupByIsbn(isbn13);
      if (gb != null) {
        await repository.putMetadataCache(
          isbn13: isbn13,
          source: LibraryRepository.metadataSourceGoogleBooks,
          payloadJson: gb.toJsonString(),
        );
        return gb;
      }
    }

    return null;
  }
}
