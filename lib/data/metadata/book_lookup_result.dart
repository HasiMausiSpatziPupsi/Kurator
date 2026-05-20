import 'dart:convert';

class BookLookupResult {
  const BookLookupResult({
    this.title,
    this.subtitle,
    this.authorsJoined,
    this.publisher,
    this.publishedYear,
    this.coverUrl,
  });

  final String? title;
  final String? subtitle;
  final String? authorsJoined;
  final String? publisher;
  final String? publishedYear;
  final String? coverUrl;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'subtitle': subtitle,
        'authorsJoined': authorsJoined,
        'publisher': publisher,
        'publishedYear': publishedYear,
        'coverUrl': coverUrl,
      };

  static BookLookupResult? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    return BookLookupResult(
      title: j['title'] as String?,
      subtitle: j['subtitle'] as String?,
      authorsJoined: j['authorsJoined'] as String?,
      publisher: j['publisher'] as String?,
      publishedYear: j['publishedYear'] as String?,
      coverUrl: j['coverUrl'] as String?,
    );
  }

  static BookLookupResult? fromJsonString(String raw) {
    try {
      final d = jsonDecode(raw) as Map<String, dynamic>;
      return fromJson(d);
    } catch (_) {
      return null;
    }
  }

  String toJsonString() => jsonEncode(toJson());
}
