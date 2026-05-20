import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/shelf_row.dart';
import '../../data/repositories/library_repository.dart';
import '../detail/copy_detail_screen.dart';
import '../../providers/providers.dart';

class ShelfListScreen extends ConsumerStatefulWidget {
  const ShelfListScreen({super.key});

  @override
  ConsumerState<ShelfListScreen> createState() => _ShelfListScreenState();
}

class _ShelfListScreenState extends ConsumerState<ShelfListScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static const double _tabletBreakpoint = 880;

  @override
  Widget build(BuildContext context) {
    final rowsAsync = ref.watch(shelfRowsProvider);
    final filter = ref.watch(shelfFilterProvider);
    final search = ref.watch(shelfSearchProvider);
    final selectedCopyId = ref.watch(shelfSelectedCopyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bibliothek'),
        actions: [
          IconButton(
            tooltip: 'Einstellungen',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Titel, Autor, ISBN…',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: search.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Leeren',
                        onPressed: () {
                          _searchController.clear();
                          ref.read(shelfSearchProvider.notifier).state = '';
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
              onChanged: (value) {
                ref.read(shelfSearchProvider.notifier).state = value;
              },
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Im Regal',
                  selected: filter == ShelfFilter.inShelf,
                  onSelected: () {
                    ref.read(shelfFilterProvider.notifier).state =
                        ShelfFilter.inShelf;
                    ref.read(shelfSelectedCopyProvider.notifier).state = null;
                  },
                ),
                _FilterChip(
                  label: 'Verliehen',
                  selected: filter == ShelfFilter.lent,
                  onSelected: () {
                    ref.read(shelfFilterProvider.notifier).state =
                        ShelfFilter.lent;
                    ref.read(shelfSelectedCopyProvider.notifier).state = null;
                  },
                ),
                _FilterChip(
                  label: 'Ausgebucht',
                  selected: filter == ShelfFilter.removed,
                  onSelected: () {
                    ref.read(shelfFilterProvider.notifier).state =
                        ShelfFilter.removed;
                    ref.read(shelfSelectedCopyProvider.notifier).state = null;
                  },
                ),
                _FilterChip(
                  label: 'Alle',
                  selected: filter == ShelfFilter.all,
                  onSelected: () {
                    ref.read(shelfFilterProvider.notifier).state =
                        ShelfFilter.all;
                    ref.read(shelfSelectedCopyProvider.notifier).state = null;
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final useSplit = constraints.maxWidth >= _tabletBreakpoint;
                return rowsAsync.when(
                  data: (rows) {
                    if (rows.isEmpty) {
                      return Center(
                        child: Text(
                          'Noch keine Einträge.\nÜber + ein Buch hinzufügen.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      );
                    }

                    void onRowTap(ShelfRow row) {
                      if (useSplit) {
                        ref.read(shelfSelectedCopyProvider.notifier).state =
                            row.copyId;
                      } else {
                        context.push('/copy/${row.copyId}');
                      }
                    }

                    final listView = ListView.separated(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: rows.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        final selected =
                            useSplit && selectedCopyId == row.copyId;
                        final isbnLine = row.isbn13 ??
                            (row.isbn10 != null && row.isbn10!.isNotEmpty
                                ? row.isbn10
                                : null);
                        return Material(
                          color: selected
                              ? Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.35)
                              : null,
                          child: ListTile(
                            title: Text(
                              row.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              [
                                if (row.authorsText != null &&
                                    row.authorsText!.trim().isNotEmpty)
                                  row.authorsText!.trim(),
                                if (isbnLine != null) 'ISBN $isbnLine',
                                if (row.locationName != null)
                                  'Ort: ${row.locationName}',
                              ].join(' · '),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: _StatusBadge(
                              status: row.status,
                              updatedAt: row.updatedAt,
                            ),
                            onTap: () => onRowTap(row),
                          ),
                        );
                      },
                    );

                    if (!useSplit) {
                      return listView;
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 5,
                          child: listView,
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          flex: 7,
                          child: selectedCopyId == null
                              ? Center(
                                  child: Text(
                                    'Exemplar links auswählen.',
                                    style:
                                        Theme.of(context).textTheme.bodyLarge,
                                  ),
                                )
                              : CopyDetailScreen(
                                  copyId: selectedCopyId,
                                  embedded: true,
                                ),
                        ),
                      ],
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(child: Text('Fehler: $e')),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'scanSeries',
            onPressed: () async {
              final code =
                  await context.push<String>('/scan?series=1');
              if (!context.mounted || code == null) return;
              await context.push('/add?isbn=${Uri.encodeComponent(code)}');
            },
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('Scan-Serie'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'scan',
            onPressed: () async {
              final code = await context.push<String>('/scan');
              if (!context.mounted || code == null) return;
              await context.push('/add?isbn=${Uri.encodeComponent(code)}');
            },
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Scannen'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: () => context.push('/add'),
            icon: const Icon(Icons.add),
            label: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.status,
    required this.updatedAt,
  });

  final String status;
  final int updatedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    late final String label;
    late final Color color;
    switch (status) {
      case CopyStatus.inShelf:
        label = 'Regal';
        color = theme.colorScheme.primary;
      case CopyStatus.lent:
        label = 'Verliehen';
        color = theme.colorScheme.tertiary;
      case CopyStatus.removed:
        label = 'Aus';
        color = theme.colorScheme.outline;
      default:
        label = status;
        color = theme.colorScheme.outline;
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(color: color),
        ),
        Text(
          DateFormat('dd.MM.yy').format(
            DateTime.fromMillisecondsSinceEpoch(updatedAt),
          ),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}
