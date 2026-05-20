import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/library_event_row.dart';
import '../../data/repositories/library_repository.dart';
import '../../providers/providers.dart';

class CopyDetailScreen extends ConsumerStatefulWidget {
  const CopyDetailScreen({
    super.key,
    required this.copyId,
    this.embedded = false,
  });

  final String copyId;

  /// Tablet Master‑Detail: ohne zweite [AppBar].
  final bool embedded;

  @override
  ConsumerState<CopyDetailScreen> createState() => _CopyDetailScreenState();
}

class _CopyDetailScreenState extends ConsumerState<CopyDetailScreen> {
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _authors;
  late final TextEditingController _publisher;
  late final TextEditingController _year;
  late final TextEditingController _language;
  late final TextEditingController _condition;
  late final TextEditingController _notes;

  String? _locationId;
  bool _loading = true;
  bool _savingMeta = false;
  CopyDetail? _copy;
  BookDetail? _book;
  List<LibraryEventRow> _events = [];
  List<LocationRow> _locations = [];

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _subtitle = TextEditingController();
    _authors = TextEditingController();
    _publisher = TextEditingController();
    _year = TextEditingController();
    _language = TextEditingController();
    _condition = TextEditingController();
    _notes = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void didUpdateWidget(CopyDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.copyId != widget.copyId) {
      setState(() {
        _loading = true;
        _copy = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _authors.dispose();
    _publisher.dispose();
    _year.dispose();
    _language.dispose();
    _condition.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final repo = await ref.read(libraryRepositoryProvider.future);
    final copy = await repo.getCopy(widget.copyId);
    if (copy == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _copy = null;
        });
      }
      return;
    }
    final book = await repo.getBook(copy.bookId);
    final events = await repo.eventsForCopy(widget.copyId);
    final locs = await repo.listLocations();
    if (!mounted) return;
    setState(() {
      _copy = copy;
      _book = book;
      _events = events;
      _locations = locs;
      _locationId = copy.locationId ?? LibraryRepository.defaultLocationId;
      _loading = false;
      if (book != null) {
        _title.text = book.title;
        _subtitle.text = book.subtitle ?? '';
        _authors.text = book.authorsText ?? '';
        _publisher.text = book.publisher ?? '';
        _year.text = book.publishedYear ?? '';
        _language.text = book.language ?? '';
      }
      _condition.text = copy.conditionText ?? '';
      _notes.text = copy.notes ?? '';
    });
  }

  Future<void> _saveBookMeta() async {
    final book = _book;
    if (book == null || _copy == null) return;
    setState(() => _savingMeta = true);
    try {
      final repo = await ref.read(libraryRepositoryProvider.future);
      await repo.updateBookMetadata(
        bookId: book.id,
        title: _title.text,
        subtitle: _subtitle.text.trim().isEmpty ? null : _subtitle.text.trim(),
        authorsText: _authors.text.trim().isEmpty ? null : _authors.text.trim(),
        publisher: _publisher.text.trim().isEmpty ? null : _publisher.text.trim(),
        publishedYear: _year.text.trim().isEmpty ? null : _year.text.trim(),
        language: _language.text.trim().isEmpty ? null : _language.text.trim(),
      );
      await repo.updateCopyNotes(
        copyId: widget.copyId,
        conditionText: _condition.text.trim().isEmpty
            ? null
            : _condition.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      ref.read(shelfRefreshProvider.notifier).state++;
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gespeichert.')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingMeta = false);
    }
  }

  Future<void> _saveLocation() async {
    if (_copy == null) return;
    final repo = await ref.read(libraryRepositoryProvider.future);
    await repo.moveCopy(copyId: widget.copyId, locationId: _locationId);
    ref.read(shelfRefreshProvider.notifier).state++;
    await _reload();
  }

  Future<void> _toggleLent(bool lent) async {
    if (_copy == null || _copy!.status == CopyStatus.removed) return;
    final repo = await ref.read(libraryRepositoryProvider.future);
    await repo.setLent(widget.copyId, lent: lent);
    ref.read(shelfRefreshProvider.notifier).state++;
    await _reload();
  }

  Future<void> _removeCopy() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        var choice = 'verkauft';
        return AlertDialog(
          title: const Text('Aus Bestand nehmen'),
          content: StatefulBuilder(
            builder: (context, setLocal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Grund auswählen:'),
                  const SizedBox(height: 8),
                  ...[
                    'verkauft',
                    'verschenkt',
                    'verloren',
                    'entsorgt',
                    'sonstiges',
                  ].map(
                    (r) => RadioListTile<String>(
                      title: Text(r),
                      value: r,
                      groupValue: choice,
                      onChanged: (v) {
                        if (v != null) setLocal(() => choice = v);
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, choice),
              child: const Text('Ausbuchen'),
            ),
          ],
        );
      },
    );
    if (reason == null || !mounted) return;
    final repo = await ref.read(libraryRepositoryProvider.future);
    await repo.removeCopy(copyId: widget.copyId, reason: reason);
    ref.read(shelfRefreshProvider.notifier).state++;
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return widget.embedded
          ? const Center(child: CircularProgressIndicator())
          : const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
    }
    if (_copy == null) {
      return widget.embedded
          ? const Center(child: Text('Eintrag nicht gefunden.'))
          : Scaffold(
              appBar: AppBar(title: const Text('Exemplar')),
              body: const Center(child: Text('Eintrag nicht gefunden.')),
            );
    }

    final copy = _copy!;
    final removed = copy.status == CopyStatus.removed;
    final dateFmt = DateFormat('dd.MM.yyyy HH:mm');

    final content = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (removed)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Ausgebucht${copy.removeReason != null ? ': ${copy.removeReason}' : ''}',
                ),
              ),
            ),
          Text(
            'Buch (Ausgabe)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Titel',
              border: OutlineInputBorder(),
            ),
            readOnly: removed,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _subtitle,
            decoration: const InputDecoration(
              labelText: 'Untertitel',
              border: OutlineInputBorder(),
            ),
            readOnly: removed,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _authors,
            decoration: const InputDecoration(
              labelText: 'Autorinnen / Autoren',
              border: OutlineInputBorder(),
            ),
            readOnly: removed,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _publisher,
            decoration: const InputDecoration(
              labelText: 'Verlag',
              border: OutlineInputBorder(),
            ),
            readOnly: removed,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _year,
            decoration: const InputDecoration(
              labelText: 'Jahr',
              border: OutlineInputBorder(),
            ),
            readOnly: removed,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _language,
            decoration: const InputDecoration(
              labelText: 'Sprache',
              border: OutlineInputBorder(),
            ),
            readOnly: removed,
          ),
          if (_book?.isbn13 != null || _book?.isbn10 != null) ...[
            const SizedBox(height: 8),
            Text(
              [
                if (_book?.isbn13 != null) 'ISBN-13: ${_book!.isbn13}',
                if (_book?.isbn10 != null) 'ISBN-10: ${_book!.isbn10}',
              ].join('   '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Exemplar',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _locationId,
            decoration: const InputDecoration(
              labelText: 'Standort',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final l in _locations)
                DropdownMenuItem(value: l.id, child: Text(l.name)),
            ],
            onChanged: removed
                ? null
                : (v) {
                    setState(() => _locationId = v);
                    // ignore: discarded_futures
                    _saveLocation();
                  },
          ),
          if (!removed) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Verliehen'),
              value: copy.status == CopyStatus.lent,
              onChanged: (v) => _toggleLent(v),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _condition,
            decoration: const InputDecoration(
              labelText: 'Zustand',
              border: OutlineInputBorder(),
            ),
            readOnly: removed,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(
              labelText: 'Notizen',
              border: OutlineInputBorder(),
            ),
            readOnly: removed,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          if (!removed)
            FilledButton.icon(
              onPressed: _savingMeta ? null : _saveBookMeta,
              icon: _savingMeta
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Metadaten & Exemplar speichern'),
            ),
          if (!removed) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _removeCopy,
              icon: const Icon(Icons.remove_circle_outline),
              label: const Text('Aus Bestand ausbuchen'),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Historie',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ..._events.map(
            (e) => ListTile(
              dense: true,
              title: Text(e.type),
              subtitle: e.detail != null && e.detail!.isNotEmpty
                  ? Text(e.detail!)
                  : null,
              trailing: Text(
                dateFmt.format(
                  DateTime.fromMillisecondsSinceEpoch(e.createdAt),
                ),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
        ],
    );

    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 0),
            child: Row(
              children: [
                Text(
                  'Exemplar',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                if (!removed)
                  IconButton(
                    tooltip: 'Aktualisieren',
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                  ),
              ],
            ),
          ),
          Expanded(child: content),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exemplar'),
        actions: [
          if (!removed)
            IconButton(
              tooltip: 'Aktualisieren',
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: content,
    );
  }
}
