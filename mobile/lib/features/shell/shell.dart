import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/repository.dart';
import '../../core/widgets/common.dart';
import '../../l10n/gen/app_localizations.dart';
import '../business/create_business_screen.dart';

/// Gate: users without a business are sent through onboarding before they see the app.
/// Adaptive navigation: bottom bar on phones, rail on wide screens.
class AppShell extends ConsumerWidget {
  final StatefulNavigationShell shell;
  const AppShell({super.key, required this.shell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final biz = ref.watch(currentBusinessProvider);
    return biz.when(
      loading: () => const Scaffold(body: SkeletonList()),
      error: (e, _) => Scaffold(body: ErrorRetry(error: e, onRetry: () => ref.invalidate(currentBusinessProvider))),
      data: (b) {
        if (b == null) return const CreateBusinessScreen();
        final dests = [
          (Icons.home_outlined, Icons.home, l.navHome),
          (Icons.calendar_month_outlined, Icons.calendar_month, l.navCalendar),
          (Icons.people_outline, Icons.people, l.navCustomers),
          (Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, l.navFinance),
          (Icons.menu, Icons.menu, l.navMore),
        ];
        void go(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);
        final wide = MediaQuery.sizeOf(context).width >= 800;
        if (wide) {
          return Scaffold(
            body: Row(children: [
              NavigationRail(
                selectedIndex: shell.currentIndex, onDestinationSelected: go, labelType: NavigationRailLabelType.all,
                destinations: [for (final d in dests) NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3))],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: shell),
            ]),
          );
        }
        return Scaffold(
          body: shell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: shell.currentIndex, onDestinationSelected: go,
            destinations: [for (final d in dests) NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3)],
          ),
        );
      },
    );
  }
}
