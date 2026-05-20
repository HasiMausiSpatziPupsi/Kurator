import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/backup/backup_service.dart';
import '../../data/repositories/library_repository.dart';
import '../../providers/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _newLocation = TextEditingController();

  @override
  void dispose() {
    _newLocation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(appSettingsProvider);
    final repoAsync = ref.watch(libraryRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          settingsAsync.when(
            data: (settings) {
              return SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Online-Metadaten'),
                subtitle: const Text(
                  'Wenn aktiv: Abruf bei Bedarf über „Metadaten suchen“ – Reihenfolge '
                  'lokaler Cache → Open Library → optional Google Books (API-Key beim Build). '
                  'Es werden keine Hintergrund-Anfragen ohne deine Aktion gesendet.',
                ),
                value: settings.metadataLookupEnabled,
                onChanged: (v) async {
                  await settings.setMetadataLookupEnabled(v);
                  ref.invalidate(appSettingsProvider);
                },
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, st) => Text('Einstellungen: $e'),
          ),
          const Divider(height: 32),
          Text(
            'Standorte',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          repoAsync.when(
            data: (repo) {
              return FutureBuilder<List<LocationRow>>(
                future: repo.listLocations(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const LinearProgressIndicator();
                  }
                  final locs = snapshot.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...locs.map(
                        (l) => ListTile(
                          title: Text(l.name),
                          dense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _newLocation,
                              decoration: const InputDecoration(
                                labelText: 'Neuer Standort',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () async {
                              final name = _newLocation.text.trim();
                              if (name.isEmpty) return;
                              await repo.addLocation(name);
                              _newLocation.clear();
                              ref.read(shelfRefreshProvider.notifier).state++;
                              setState(() {});
                            },
                            child: const Text('Hinzufügen'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, st) => Text('Fehler: $e'),
          ),
          const Divider(height: 32),
          Text(
            'Backup',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'ZIP enthält die SQLite-Datenbank und eine manifest.json mit Zeitstempel und SHA-256. '
            'Import ersetzt die lokale Datenbank und startet die App neu.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
              try {
                await BackupService.exportZip(ref);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Backup gespeichert.')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Export: $e')),
                );
              }
            },
            icon: const Icon(Icons.save_alt_outlined),
            label: const Text('Backup exportieren (ZIP)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Backup einspielen?'),
                  content: const Text(
                    'Die aktuelle Bibliothek wird durch die ZIP-Datei ersetzt. '
                    'Die App startet danach neu.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Abbrechen'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Ersetzen'),
                    ),
                  ],
                ),
              );
              if (ok != true || !context.mounted) return;
              try {
                await BackupService.importZipReplace(ref);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Import: $e')),
                );
              }
            },
            icon: const Icon(Icons.restore_outlined),
            label: const Text('Backup importieren (ZIP)'),
          ),
          const Divider(height: 32),
          Text(
            'Datenschutz (Kurzfassung)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Die App speichert deine Bibliothek lokal auf dem Gerät. '
            'Netzwerkzugriff erfolgt nur mit aktivem Schalter und wenn du '
            '„Metadaten suchen“ nutzt. Open Library (openlibrary.org/privacy); '
            'Google Books nur mit konfiguriertem API-Key (Google APIs Terms).',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => context.pop(),
            child: const Text('Zurück'),
          ),
        ],
      ),
    );
  }
}
