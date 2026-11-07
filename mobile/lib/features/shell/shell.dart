import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/repository.dart';
import '../../core/design/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../l10n/gen/app_localizations.dart';
import '../business/create_business_screen.dart';

/// Gate: users without a business are sent through onboarding before they see the app.
/// Adaptive navigation: bottom bar on phones, icon rail on tablets, full sidebar on desktop.
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
          NavItem(Icons.home_outlined, Icons.home_rounded, l.navHome),
          NavItem(Icons.calendar_month_outlined, Icons.calendar_month_rounded, l.navCalendar),
          NavItem(Icons.people_outline_rounded, Icons.people_rounded, l.navCustomers),
          NavItem(Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded, l.navFinance),
          NavItem(Icons.grid_view_outlined, Icons.grid_view_rounded, l.navMore),
        ];
        void go(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);
        final width = MediaQuery.sizeOf(context).width;
        // Keep the active tab's screen centered with a readable max width on very large screens.
        final body = Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1180), child: shell));
        if (AppBreakpoints.isWide(context)) {
          return Scaffold(
            body: Row(children: [
              AppSidebar(items: dests, selectedIndex: shell.currentIndex, onSelect: go, title: b.name, extended: width >= AppBreakpoints.expanded),
              Expanded(child: body),
            ]),
          );
        }
        return Scaffold(
          body: shell,
          bottomNavigationBar: DecoratedBox(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant))),
            child: NavigationBar(
              selectedIndex: shell.currentIndex, onDestinationSelected: go,
              destinations: [for (final d in dests) NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label, tooltip: d.label)],
            ),
          ),
        );
      },
    );
  }
}
