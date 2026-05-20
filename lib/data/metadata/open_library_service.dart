import 'package:dio/dio.dart';

import 'book_lookup_result.dart';

/// Open Library (openlibrary.org) – nur nutzen wenn Nutzer Opt-in gesetzt hat.
class OpenLibraryService {
  OpenLibraryService(this._dio);

  final Dio _dio;

  /// [isbn] ohne Bindestriche (ISBN-10 oder ISBN-13).
  Future<BookLookupResult?> lookupByIsbn(String isbn) async {
    final key = 'ISBN:$isbn';
    final response = await _dio.get<Map<String, dynamic>>(
      'https://openlibrary.org/api/books',
      queryParameters: <String, dynamic>{
        'bibkeys': key,
        'format': 'json',
        'jscmd': 'data',
      },
      options: Options(
        headers: <String, String>{
          'User-Agent': 'InventurApp/1.0 (private library)',
        },
      ),
    );

    final root = response.data;
    if (root == null || !root.containsKey(key)) return null;
    final book = root[key];
    if (book is! Map<String, dynamic>) return null;

    final title = book['title'] as String?;
    final subtitle = book['subtitle'] as String?;

    String? authorsJoined;
    final authors = book['authors'];
    if (authors is List<dynamic>) {
      final names = <String>[];
      for (final a in authors) {
        if (a is Map && a['name'] is String) {
          names.add(a['name'] as String);
        }
      }
      if (names.isNotEmpty) authorsJoined = names.join(', ');
    }

    String? publisher;
    final publishers = book['publishers'];
    if (publishers is List<dynamic> && publishers.isNotEmpty) {
      final p0 = publishers.first;
      if (p0 is Map && p0['name'] is String) {
        publisher = p0['name'] as String;
      }
    }

    String? publishedYear;
    final pd = book['publish_date'];
    if (pd is String) {
      final m = RegExp(r'\d{4}').firstMatch(pd);
      publishedYear = m?.group(0) ?? pd;
    }

    String? coverUrl;
    final cover = book['cover'];
    if (cover is Map) {
      coverUrl =
          (cover['medium'] ?? cover['large'] ?? cover['small']) as String?;
    }

    if (title == null && authorsJoined == null && publisher == null) {
      return null;
    }

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
