/// ISBN-Hilfen: Normalisierung und Prüfziffer (ISBN-10 inkl. X, ISBN-13).
class IsbnUtils {
  IsbnUtils._();

  static String normalizeInput(String raw) {
    return raw.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
  }

  /// Nur Ziffern (ISBN-13) oder Ziffern+X am Ende (ISBN-10).
  static bool looksLikeIsbn(String normalized) {
    if (normalized.isEmpty) return false;
    final isbn10 = RegExp(r'^\d{9}[\dX]$');
    final isbn13 = RegExp(r'^\d{13}$');
    return isbn10.hasMatch(normalized) || isbn13.hasMatch(normalized);
  }

  static bool isValidIsbn10(String normalized) {
    if (!RegExp(r'^\d{9}[\dX]$').hasMatch(normalized)) return false;
    var sum = 0;
    for (var i = 0; i < 9; i++) {
      sum += (i + 1) * int.parse(normalized[i]);
    }
    final last = normalized[9];
    final check = last == 'X' ? 10 : int.parse(last);
    return sum % 11 == check;
  }

  static bool isValidIsbn13(String normalized) {
    if (!RegExp(r'^\d{13}$').hasMatch(normalized)) return false;
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      final n = int.parse(normalized[i]);
      sum += (i % 2 == 0) ? n : n * 3;
    }
    final check = (10 - (sum % 10)) % 10;
    return check == int.parse(normalized[12]);
  }

  static bool isValid(String normalized) {
    if (normalized.length == 10) return isValidIsbn10(normalized);
    if (normalized.length == 13) return isValidIsbn13(normalized);
    return false;
  }

  /// ISBN-10 [9 digits + check] zu ISBN-13 (ohne Bindestriche).
  static String? isbn10ToIsbn13(String normalized10) {
    if (!isValidIsbn10(normalized10)) return null;
    const prefix = '978';
    final core = '$prefix${normalized10.substring(0, 9)}';
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      final n = int.parse(core[i]);
      sum += (i % 2 == 0) ? n : n * 3;
    }
    final d13 = (10 - (sum % 10)) % 10;
    return '$core$d13';
  }

  /// Liefert (isbn13, isbn10) wenn möglich; sonst null bei ungültig.
  static ({String? isbn13, String? isbn10})? parseAndSplit(String raw) {
    final n = normalizeInput(raw);
    if (!looksLikeIsbn(n)) return null;
    if (n.length == 13) {
      if (!isValidIsbn13(n)) return null;
      return (isbn13: n, isbn10: null);
    }
    if (n.length == 10) {
      if (!isValidIsbn10(n)) return null;
      final i13 = isbn10ToIsbn13(n);
      return (isbn13: i13, isbn10: n);
    }
    return null;
  }
}
