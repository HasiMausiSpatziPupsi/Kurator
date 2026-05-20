class LibraryEventRow {
  const LibraryEventRow({
    required this.id,
    required this.type,
    required this.createdAt,
    this.detail,
  });

  final String id;
  final String type;
  final String? detail;
  final int createdAt;

  static LibraryEventRow fromMap(Map<String, Object?> m) {
    return LibraryEventRow(
      id: m['id']! as String,
      type: m['type']! as String,
      detail: m['detail'] as String?,
      createdAt: m['created_at']! as int,
    );
  }
}
