import 'package:go_router/go_router.dart';

import '../features/add/add_item_flow_screen.dart';
import '../features/detail/copy_detail_screen.dart';
import '../features/scan/scan_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shelf/shelf_list_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      name: 'shelf',
      builder: (context, state) => const ShelfListScreen(),
    ),
    GoRoute(
      path: '/add',
      name: 'add',
      builder: (context, state) {
        final isbn = state.uri.queryParameters['isbn'];
        return AddItemFlowScreen(initialIsbn: isbn);
      },
    ),
    GoRoute(
      path: '/copy/:id',
      name: 'copy',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return CopyDetailScreen(copyId: id);
      },
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/scan',
      name: 'scan',
      builder: (context, state) {
        final series = state.uri.queryParameters['series'] == '1';
        return ScanScreen(seriesMode: series);
      },
    ),
  ],
);
