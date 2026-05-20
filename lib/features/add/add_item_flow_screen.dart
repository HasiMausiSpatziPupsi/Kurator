import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/library_repository.dart';
import '../../providers/providers.dart';
import '../../utils/isbn_utils.dart';

class AddItemFlowScreen extends ConsumerStatefulWidget {
  const AddItemFlowScreen({super.key, this.initialIsbn});

  final String? initialIsbn;

  @override
  ConsumerState<AddItemFlowScreen> createState() => _AddItemFlowScreenState();
}

class _AddItemFlowScreenState extends ConsumerState<AddItemFlowScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  final _manualTitle = TextEditingController();
  final _manualSubtitle = TextEditingController();
  final _manualAuthors = TextEditingController();
  final _manualIsbn = TextEditingController();
  final _manualPublisher = TextEditingController();
  final _manualYear = TextEditingController();
  final _manualCondition = TextEditingController();
  final _manualNotes = TextEditingController();

  final _isbnField = TextEditingController();
  final _isbnTitle = TextEditingController();
  final _isbnSubtitle = TextEditingController();
  final _isbnAuthors = TextEditingController();
  final _isbnPublisher = TextEditingController();
  final _isbnYear = TextEditingController();
  final _isbnCondition = TextEditingController();
  final _isbnNotes = TextEditingController();

  String? _locationId;
  bool _saving = false;
  String? _lookupMessage;
  bool _isbnLookupApplied = false;
  String? _isbnCoverUrl;
  bool _dupHintScheduled = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    if (widget.initialIsbn != null && widget.initialIsbn!.isNotEmpty) {
      _isbnField.text = widget.initialIsbn!;
      _tabs.index = 1;
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _manualTitle.dispose();
    _manualSubtitle.dispose();
    _manualAuthors.dispose();
    _manualIsbn.dispose();
    _manualPublisher.dispose();
    _manualYear.dispose();
    _manualCondition.dispose();
    _manualNotes.dispose();
    _isbnField.dispose();
    _isbnTitle.dispose();
    _isbnSubtitle.dispose();
    _isbnAuthors.dispose();
    _isbnPublisher.dispose();
    _isbnYear.dispose();
    _isbnCondition.dispose();
    _isbnNotes.dispose();
    super.dispose();
  }

  Future<void> _loadLocationsFirst(LibraryRepository repo) async {
    if (_locationId != null) return;
    final locs = await repo.listLocations();
    if (locs.isEmpty) return;
    setState(() {
      _locationId = LibraryRepository.defaultLocationId;
    });
  }

  Future<void> _lookupIsbn(LibraryRepository repo) async {
    final settings = await ref.read(appSettingsProvider.future);
    if (!settings.metadataLookupEnabled) {
      setState(() {
        _lookupMessage =
            'Metadaten-Abfrage ist aus. Aktiviere sie in den Einstellungen.';
      });
      return;
    }

    final normalized = IsbnUtils.normalizeInput(_isbnField.text);
    final parsed = IsbnUtils.parseAndSplit(normalized);
    if (parsed == null || parsed.isbn13 == null) {
      setState(() => _lookupMessage = 'Keine gültige ISBN.');
      return;
    }

    setState(() {
      _lookupMessage = 'Lade Metadaten…';
    });

    try {
      final aggregator = ref.read(metadataAggregatorProvider);
      final meta = await aggregator.lookupIsbn13(
        isbn13: parsed.isbn13!,
        repository: repo,
        allowNetwork: true,
      );
      if (!mounted) return;
      if (meta == null) {
        setState(() {
          _isbnCoverUrl = null;
          _lookupMessage =
              'Kein Treffer (Open Library / Google Books). Felder manuell ausfüllen.';
        });
        return;
      }
      setState(() {
        _isbnCoverUrl = meta.coverUrl;
        _isbnLookupApplied = true;
        if (meta.title != null) _isbnTitle.text = meta.title!;
        if (meta.subtitle != null) _isbnSubtitle.text = meta.subtitle!;
        if (meta.authorsJoined != null) _isbnAuthors.text = meta.authorsJoined!;
        if (meta.publisher != null) _isbnPublisher.text = meta.publisher!;
        if (meta.publishedYear != null) _isbnYear.text = meta.publishedYear!;
        _lookupMessage = 'Metadaten übernommen (bitte prüfen).';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lookupMessage = 'Abfrage fehlgeschlagen: $e';
      });
    }
  }

  Future<void> _saveManual(LibraryRepository repo) async {
    final title = _manualTitle.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Titel ist Pflicht.')),
      );
      return;
    }

    String? i13;
    String? i10;
    final rawIsbn = _manualIsbn.text.trim();
    if (rawIsbn.isNotEmpty) {
      final parsed = IsbnUtils.parseAndSplit(IsbnUtils.normalizeInput(rawIsbn));
      if (parsed == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ISBN ungültig oder unbekanntes Format.')),
        );
        return;
      }
      i13 = parsed.isbn13;
      i10 = parsed.isbn10;
    }

    setState(() => _saving = true);
    try {
      await repo.addManualCopy(
        title: title,
        subtitle: _manualSubtitle.text.trim().isEmpty
            ? null
            : _manualSubtitle.text.trim(),
        authorsText: _manualAuthors.text.trim().isEmpty
            ? null
            : _manualAuthors.text.trim(),
        isbn13: i13,
        isbn10: i10,
        publisher: _manualPublisher.text.trim().isEmpty
            ? null
            : _manualPublisher.text.trim(),
        publishedYear: _manualYear.text.trim().isEmpty
            ? null
            : _manualYear.text.trim(),
        locationId: _locationId,
        conditionText: _manualCondition.text.trim().isEmpty
            ? null
            : _manualCondition.text.trim(),
        notes: _manualNotes.text.trim().isEmpty ? null : _manualNotes.text.trim(),
      );
      ref.read(shelfRefreshProvider.notifier).state++;
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveIsbn(LibraryRepository repo) async {
    final normalized = IsbnUtils.normalizeInput(_isbnField.text);
    final parsed = IsbnUtils.parseAndSplit(normalized);
    if (parsed == null || parsed.isbn13 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ISBN prüfen (ISBN-10 oder ISBN-13).')),
      );
      return;
    }

    final title = _isbnTitle.text.trim().isEmpty
        ? 'ISBN ${parsed.isbn13!}'
        : _isbnTitle.text.trim();

    setState(() => _saving = true);
    try {
      await repo.addCopyForIsbn(
        isbn13: parsed.isbn13!,
        isbn10: parsed.isbn10,
        prefilledTitle: title,
        subtitle: _isbnSubtitle.text.trim().isEmpty
            ? null
            : _isbnSubtitle.text.trim(),
        authorsText: _isbnAuthors.text.trim().isEmpty
            ? null
            : _isbnAuthors.text.trim(),
        publisher: _isbnPublisher.text.trim().isEmpty
            ? null
            : _isbnPublisher.text.trim(),
        publishedYear:
            _isbnYear.text.trim().isEmpty ? null : _isbnYear.text.trim(),
        coverUrl: _isbnCoverUrl,
        metadataManual: !_isbnLookupApplied,
        locationId: _locationId,
        conditionText: _isbnCondition.text.trim().isEmpty
            ? null
            : _isbnCondition.text.trim(),
        notes: _isbnNotes.text.trim().isEmpty ? null : _isbnNotes.text.trim(),
      );
      ref.read(shelfRefreshProvider.notifier).state++;
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _maybeWarnDuplicateExemplare() async {
    if (widget.initialIsbn == null || widget.initialIsbn!.isEmpty) return;
    final normalized = IsbnUtils.normalizeInput(widget.initialIsbn!);
    final parsed = IsbnUtils.parseAndSplit(normalized);
    if (parsed?.isbn13 == null) return;
    final repo = await ref.read(libraryRepositoryProvider.future);
    final dups = await repo.copiesInShelfForIsbn13(parsed!.isbn13!);
    if (!mounted || dups.length <= 1) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mehrere Exemplare'),
        content: Text(
          'Zu dieser ISBN liegen bereits ${dups.length} Exemplare im Regal. '
          'Du kannst ein weiteres anlegen oder in der Bibliothek ein bestehendes öffnen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_dupHintScheduled && widget.initialIsbn != null) {
      _dupHintScheduled = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _maybeWarnDuplicateExemplare());
    }

    final repoAsync = ref.watch(libraryRepositoryProvider);

    return repoAsync.when(
      data: (repo) {
        // ignore: discarded_futures
        _loadLocationsFirst(repo);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Buch hinzufügen'),
            bottom: TabBar(
              controller: _tabs,
              tabs: const [
                Tab(text: 'Manuell'),
                Tab(text: 'ISBN'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabs,
            children: [
              _ManualTab(
                title: _manualTitle,
                subtitle: _manualSubtitle,
                authors: _manualAuthors,
                isbn: _manualIsbn,
                publisher: _manualPublisher,
                year: _manualYear,
                condition: _manualCondition,
                notes: _manualNotes,
                locationId: _locationId,
                onLocationChanged: (v) => setState(() => _locationId = v),
                locationsFuture: repo.listLocations(),
                saving: _saving,
                onSave: () => _saveManual(repo),
              ),
              _IsbnTab(
                isbn: _isbnField,
                title: _isbnTitle,
                subtitle: _isbnSubtitle,
                authors: _isbnAuthors,
                publisher: _isbnPublisher,
                year: _isbnYear,
                condition: _isbnCondition,
                notes: _isbnNotes,
                locationId: _locationId,
                onLocationChanged: (v) => setState(() => _locationId = v),
                locationsFuture: repo.listLocations(),
                lookupMessage: _lookupMessage,
                onLookup: () => _lookupIsbn(repo),
                saving: _saving,
                onSave: () => _saveIsbn(repo),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => Scaffold(
        body: Center(child: Text('Datenbank: $e')),
      ),
    );
  }
}

class _ManualTab extends StatelessWidget {
  const _ManualTab({
    required this.title,
    required this.subtitle,
    required this.authors,
    required this.isbn,
    required this.publisher,
    required this.year,
    required this.condition,
    required this.notes,
    required this.locationId,
    required this.onLocationChanged,
    required this.locationsFuture,
    required this.saving,
    required this.onSave,
  });

  final TextEditingController title;
  final TextEditingController subtitle;
  final TextEditingController authors;
  final TextEditingController isbn;
  final TextEditingController publisher;
  final TextEditingController year;
  final TextEditingController condition;
  final TextEditingController notes;
  final String? locationId;
  final ValueChanged<String?> onLocationChanged;
  final Future<List<LocationRow>> locationsFuture;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: title,
          decoration: const InputDecoration(
            labelText: 'Titel *',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: subtitle,
          decoration: const InputDecoration(
            labelText: 'Untertitel',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: authors,
          decoration: const InputDecoration(
            labelText: 'Autorinnen / Autoren',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: isbn,
          decoration: const InputDecoration(
            labelText: 'ISBN (optional)',
            border: OutlineInputBorder(),
            hintText: 'ISBN-10 oder ISBN-13',
          ),
          keyboardType: TextInputType.text,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: publisher,
          decoration: const InputDecoration(
            labelText: 'Verlag',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: year,
          decoration: const InputDecoration(
            labelText: 'Jahr',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<LocationRow>>(
          future: locationsFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const LinearProgressIndicator();
            }
            final locs = snapshot.data!;
            return DropdownButtonFormField<String>(
              initialValue: locationId ?? LibraryRepository.defaultLocationId,
              decoration: const InputDecoration(
                labelText: 'Standort',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final l in locs)
                  DropdownMenuItem(value: l.id, child: Text(l.name)),
              ],
              onChanged: saving ? null : onLocationChanged,
            );
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: condition,
          decoration: const InputDecoration(
            labelText: 'Zustand (Exemplar)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: notes,
          decoration: const InputDecoration(
            labelText: 'Notizen (Exemplar)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: saving ? null : onSave,
          icon: saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('Speichern'),
        ),
      ],
    );
  }
}

class _IsbnTab extends StatelessWidget {
  const _IsbnTab({
    required this.isbn,
    required this.title,
    required this.subtitle,
    required this.authors,
    required this.publisher,
    required this.year,
    required this.condition,
    required this.notes,
    required this.locationId,
    required this.onLocationChanged,
    required this.locationsFuture,
    required this.lookupMessage,
    required this.onLookup,
    required this.saving,
    required this.onSave,
  });

  final TextEditingController isbn;
  final TextEditingController title;
  final TextEditingController subtitle;
  final TextEditingController authors;
  final TextEditingController publisher;
  final TextEditingController year;
  final TextEditingController condition;
  final TextEditingController notes;
  final String? locationId;
  final ValueChanged<String?> onLocationChanged;
  final Future<List<LocationRow>> locationsFuture;
  final String? lookupMessage;
  final VoidCallback onLookup;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: isbn,
          decoration: const InputDecoration(
            labelText: 'ISBN',
            border: OutlineInputBorder(),
            hintText: 'Mit oder ohne Bindestriche',
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: saving ? null : onLookup,
          icon: const Icon(Icons.cloud_download_outlined),
          label: const Text('Metadaten suchen (Cache / Online)'),
        ),
        if (lookupMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            lookupMessage!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: title,
          decoration: const InputDecoration(
            labelText: 'Titel *',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: subtitle,
          decoration: const InputDecoration(
            labelText: 'Untertitel',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: authors,
          decoration: const InputDecoration(
            labelText: 'Autorinnen / Autoren',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: publisher,
          decoration: const InputDecoration(
            labelText: 'Verlag',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: year,
          decoration: const InputDecoration(
            labelText: 'Jahr',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<LocationRow>>(
          future: locationsFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const LinearProgressIndicator();
            }
            final locs = snapshot.data!;
            return DropdownButtonFormField<String>(
              initialValue: locationId ?? LibraryRepository.defaultLocationId,
              decoration: const InputDecoration(
                labelText: 'Standort',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final l in locs)
                  DropdownMenuItem(value: l.id, child: Text(l.name)),
              ],
              onChanged: saving ? null : onLocationChanged,
            );
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: condition,
          decoration: const InputDecoration(
            labelText: 'Zustand (Exemplar)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: notes,
          decoration: const InputDecoration(
            labelText: 'Notizen (Exemplar)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: saving ? null : onSave,
          icon: saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('Exemplar speichern'),
        ),
      ],
    );
  }
}
