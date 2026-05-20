class ShelfRow {
  const ShelfRow({
    required this.copyId,
    required this.bookId,
    required this.title,
    required this.status,
    required this.updatedAt,
    this.subtitle,
    this.authorsText,
    this.isbn13,
    this.isbn10,
    this.locationName,
    this.conditionText,
    this.notes,
  });

  final String copyId;
  final String bookId;
  final String title;
  final String? subtitle;
  final String? authorsText;
  final String? isbn13;
  final String? isbn10;
  final String status;
  final String? locationName;
  final String? conditionText;
  final String? notes;
  final int updatedAt;

  static ShelfRow fromMap(Map<String, Object?> m) {
    return ShelfRow(
      copyId: m['copy_id']! as String,
      bookId: m['book_id']! as String,
      title: m['title']! as String,
      subtitle: m['subtitle'] as String?,
      authorsText: m['authors_text'] as String?,
      isbn13: m['isbn13'] as String?,
      isbn10: m['isbn10'] as String?,
      status: m['status']! as String,
      locationName: m['location_name'] as String?,
      conditionText: m['condition_text'] as String?,
      notes: m['notes'] as String?,
      updatedAt: m['updated_at']! as int,
    );
  }
}
