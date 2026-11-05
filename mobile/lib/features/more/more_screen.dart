import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/auth_controller.dart';
import '../../core/data/repository.dart';
import '../../core/design/tokens.dart';
import '../../core/settings/settings.dart';
import '../../l10n/gen/app_localizations.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  static const _names = {'kk': 'Қазақша', 'ru': 'Русский', 'en': 'English'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final usage = ref.watch(usageProvider).value;
    final current = settings.locale?.languageCode ?? Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(l.navMore)),
      body: ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
        if (usage != null) Card(
          child: ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: Text('${l.plan}: ${usage.planCode}'),
            subtitle: Text(l.planUsage(usage.employees, usage.maxEmployees)),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final e in [
          (Icons.rocket_launch_outlined, l.setupNav, '/more/setup'),
          (Icons.storefront_outlined, l.branches, '/more/branches'),
          (Icons.content_cut, l.services, '/more/services'),
          (Icons.badge_outlined, l.employees, '/more/employees'),
        ]) Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Card(child: ListTile(leading: Icon(e.$1), title: Text(e.$2), trailing: const Icon(Icons.chevron_right), onTap: () => context.push(e.$3))),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(l.language, style: t.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<String>(
          segments: [for (final e in _names.entries) ButtonSegment(value: e.key, label: Text(e.value))],
          selected: {current},
          onSelectionChanged: (s) => ref.read(settingsProvider.notifier).setLocale(Locale(s.first)),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(l.theme, style: t.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<ThemeMode>(
          segments: [
            ButtonSegment(value: ThemeMode.system, label: Text(l.themeSystem)),
            ButtonSegment(value: ThemeMode.light, label: Text(l.themeLight)),
            ButtonSegment(value: ThemeMode.dark, label: Text(l.themeDark)),
          ],
          selected: {settings.themeMode},
          onSelectionChanged: (s) => ref.read(settingsProvider.notifier).setThemeMode(s.first),
        ),
        const SizedBox(height: AppSpacing.xl),
        OutlinedButton.icon(
          icon: const Icon(Icons.logout),
          label: Text(l.logout),
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
        ),
      ]),
    );
  }
}
