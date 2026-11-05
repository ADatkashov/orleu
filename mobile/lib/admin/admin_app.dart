import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/data/auth_controller.dart';
import '../core/design/theme.dart';
import 'admin_screens.dart';

class _Refresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

final adminRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _Refresh();
  ref.listen(authControllerProvider, (_, _) => refresh.ping());
  ref.onDispose(refresh.dispose);
  return GoRouter(
    initialLocation: '/businesses',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      return switch (auth) {
        AuthStatus.unknown => loc == '/splash' ? null : '/splash',
        AuthStatus.unauthenticated => loc == '/login' ? null : '/login',
        AuthStatus.authenticated => loc == '/login' || loc == '/splash' ? '/businesses' : null,
      };
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const Scaffold(body: Center(child: CircularProgressIndicator()))),
      GoRoute(path: '/login', builder: (_, _) => const AdminLoginScreen()),
      ShellRoute(
        builder: (_, state, child) => AdminShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/businesses', builder: (_, _) => const BusinessesScreen(), routes: [
            GoRoute(path: ':id', builder: (_, state) => BusinessDetailScreen(id: state.pathParameters['id']!)),
          ]),
          GoRoute(path: '/plans', builder: (_, _) => const PlansScreen()),
          GoRoute(path: '/audit', builder: (_, state) => AuditScreen(initialBusinessId: state.uri.queryParameters['businessId'] ?? '')),
        ],
      ),
    ],
  );
});

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'ORLEU Admin',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        routerConfig: ref.watch(adminRouterProvider),
      );
}
