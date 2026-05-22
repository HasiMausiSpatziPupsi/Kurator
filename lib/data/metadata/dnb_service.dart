import 'package:dio/dio.dart';
import 'package:xml/xml.dart';
import 'book_lookup_result.dart';

/// Deutsche Nationalbibliothek (DNB) SRU API.
/// Nutzt das MARC21-xml Format für detaillierte bibliografische Daten.
class DnbService {
  DnbService(this._dio);

  final Dio _dio;
  static const String _baseUrl = 'https://services.dnb.de/sru/dnb';

  Future<BookLookupResult?> lookupByIsbn(String isbn) async {
    try {
      final response = await _dio.get<String>(
        _baseUrl,
        queryParameters: <String, dynamic>{
          'version': '1.1',
          'operation': 'searchRetrieve',
          'query': 'isbn=$isbn',
          'recordSchema': 'MARC21-xml',
        },
      );

      if (response.statusCode != 200 || response.data == null) {
        return null;
      }

      final document = XmlDocument.parse(response.data!);
      final records = document.findAllElements('record');

      if (records.isEmpty) {
        return null;
      }

      // Wir nehmen den ersten Treffer
      final record = records.first;

      final title = _getMarcField(record, '245', 'a');
      final subtitle = _getMarcField(record, '245', 'b');

      // Autoren: 100a (Hauptautor) oder 700a (Mitwirkende)
      String? authors = _getMarcField(record, '100', 'a');
      if (authors == null) {
        final contributors = record.findAllElements('datafield')
            .where((e) => e.getAttribute('tag') == '700')
            .map((e) => _getSubfield(e, 'a'))
            .whereType<String>()
            .join(', ');
        if (contributors.isNotEmpty) {
          authors = contributors;
        }
      }

      final publisher = _getMarcField(record, '264', 'b') ?? _getMarcField(record, '260', 'b');

      String? year = _getMarcField(record, '264', 'c') ?? _getMarcField(record, '260', 'c');
      if (year != null) {
        // Bereinigen (oft stehen da Dinge wie "c2023" oder "[2023]")
        final match = RegExp(r'\d{4}').firstMatch(year);
        year = match?.group(0) ?? year;
      }

      if (title == null && authors == null) {
        return null;
      }

      return BookLookupResult(
        title: title,
        subtitle: subtitle,
        authorsJoined: authors,
        publisher: publisher,
        publishedYear: year,
      );
    } catch (e) {
      // Loggen oder Fehlerbehandlung
      return null;
    }
  }

  String? _getMarcField(XmlElement record, String tag, String subfieldCode) {
    try {
      final field = record.findAllElements('datafield').firstWhere(
            (e) => e.getAttribute('tag') == tag,
            orElse: () => throw Exception('Field not found'),
          );
      return _getSubfield(field, subfieldCode);
    } catch (_) {
      return null;
    }
  }

  String? _getSubfield(XmlElement field, String code) {
    try {
      final subfield = field.findElements('subfield').firstWhere(
            (e) => e.getAttribute('code') == code,
            orElse: () => throw Exception('Subfield not found'),
          );
      final text = subfield.innerText.trim();

      // MARC21 Titel enden oft auf " /" oder "." - wir putzen das weg
      return text.replaceAll(RegExp(r'\s*/$'), '').replaceAll(RegExp(r'\.$'), '').trim();
    } catch (_) {
      return null;
    }
  }
}
