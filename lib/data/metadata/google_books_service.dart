import 'package:dio/dio.dart';

import 'book_lookup_result.dart';

/// Google Books API – nur mit API-Key (`--dart-define=GOOGLE_BOOKS_API_KEY=...`).
class GoogleBooksService {
  GoogleBooksService(this._dio);

  final Dio _dio;

  static const apiKey =
      String.fromEnvironment('GOOGLE_BOOKS_API_KEY', defaultValue: '');

  bool get isConfigured => apiKey.isNotEmpty;

  /// [isbn] bevorzugt ISBN-13.
  Future<BookLookupResult?> lookupByIsbn(String isbn) async {
    if (!isConfigured) return null;
    final response = await _dio.get<Map<String, dynamic>>(
      'https://www.googleapis.com/books/v1/volumes',
      queryParameters: <String, dynamic>{
        'q': 'isbn:$isbn',
        'key': apiKey,
        'maxResults': 1,
      },
    );

    final items = response.data?['items'] as List<dynamic>?;
    if (items == null || items.isEmpty) return null;
    final first = items.first;
    if (first is! Map<String, dynamic>) return null;
    final vol = first['volumeInfo'];
    if (vol is! Map<String, dynamic>) return null;

    final title = vol['title'] as String?;
    final subtitle = vol['subtitle'] as String?;

    String? authorsJoined;
    final authors = vol['authors'];
    if (authors is List<dynamic>) {
      authorsJoined = authors.whereType<String>().join(', ');
    }

    String? publisher = vol['publisher'] as String?;
    String? publishedYear;
    final pd = vol['publishedDate'];
    if (pd is String) {
      final m = RegExp(r'\d{4}').firstMatch(pd);
      publishedYear = m?.group(0) ?? pd;
    }

    String? coverUrl;
    final img = vol['imageLinks'];
    if (img is Map) {
      coverUrl = (img['thumbnail'] ?? img['smallThumbnail']) as String?;
      if (coverUrl != null && coverUrl.startsWith('http:')) {
        coverUrl = coverUrl.replaceFirst('http:', 'https:');
      }
    }

    if (title == null && authorsJoined == null) return null;

    return BookLookupResult(
      title: title,
      subtitle: subtitle,
      authorsJoined: authorsJoined,
      publisher: publisher,
      publishedYear: publishedYear,
      coverUrl: coverUrl,
    );
  }
}
