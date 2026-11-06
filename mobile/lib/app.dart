import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/data/auth_controller.dart';
import 'core/design/theme.dart';
import 'core/settings/settings.dart';
import 'features/auth/auth_screens.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/customers/customer_profile_screen.dart';
import 'features/customers/customers_screen.dart';
import 'features/finance/finance_screen.dart';
import 'features/home/home_screen.dart';
import 'features/more/more_screen.dart';
import 'features/more/messages_screen.dart';
import 'features/more/account_screen.dart';
import 'features/more/reviews_screen.dart';
import 'features/more/support_screen.dart';
import 'features/setup/branches_screen.dart';
import 'features/setup/employees_screen.dart';
import 'features/setup/services_screen.dart';
import 'features/setup/setup_screen.dart';
import 'features/shell/shell.dart';
import 'l10n/gen/app_localizations.dart';

class _AuthRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh();
  ref.listen(authControllerProvider, (_, _) => refresh.ping());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      final onAuth = loc == '/login' || loc == '/register' || loc == '/forgot';
      switch (auth) {
        case AuthStatus.unknown:
          return loc == '/splash' ? null : '/splash';
        case AuthStatus.unauthenticated:
          return onAuth ? null : '/login';
        case AuthStatus.authenticated:
          return onAuth || loc == '/splash' ? '/home' : null;
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const Scaffold(body: Center(child: CircularProgressIndicator()))),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/forgot', builder: (_, _) => const ForgotPasswordScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/calendar', builder: (_, _) => const CalendarScreen())]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/customers', builder: (_, _) => const CustomersScreen(), routes: [
              GoRoute(path: ':id', builder: (_, state) => CustomerProfileScreen(customerId: state.pathParameters['id']!)),
            ]),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: '/finance', builder: (_, _) => const FinanceScreen())]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/more', builder: (_, _) => const MoreScreen(), routes: [
              GoRoute(path: 'setup', builder: (_, _) => const SetupScreen()),
              GoRoute(path: 'branches', builder: (_, _) => const BranchesScreen()),
              GoRoute(path: 'services', builder: (_, _) => const ServicesScreen()),
              GoRoute(path: 'employees', builder: (_, _) => const EmployeesScreen()),
              GoRoute(path: 'messages', builder: (_, _) => const MessagesScreen()),
              GoRoute(path: 'account', builder: (_, _) => const AccountScreen()),
              GoRoute(path: 'reviews', builder: (_, _) => const ReviewsScreen()),
              GoRoute(path: 'support', builder: (_, _) => const SupportScreen(), routes: [
                GoRoute(path: ':id', builder: (_, state) => TicketScreen(id: state.pathParameters['id']!)),
              ]),
            ]),
          ]),
        ],
      ),
    ],
  );
});

class OrleuApp extends ConsumerWidget {
  const OrleuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp.router(
      title: 'ORLEU',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
    );
  }
}
