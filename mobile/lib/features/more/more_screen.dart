import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/auth_controller.dart';
import '../../core/data/repository.dart';
import '../../core/design/tokens.dart';
import '../../core/settings/settings.dart';
import '../../core/widgets/widgets.dart';
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
    final biz = ref.watch(currentBusinessProvider).value;
    final current = settings.locale?.languageCode ?? Localizations.localeOf(context).languageCode;
    SettingsTile tile(IconData icon, String label, String route) => SettingsTile(icon: icon, title: label, onTap: () => context.push(route));
    final gutter = AppSpacing.gutter(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.navMore)),
      body: ListView(padding: EdgeInsets.fromLTRB(gutter, AppSpacing.sm, gutter, AppSpacing.xl), children: [
        if (usage != null)
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                AppAvatar(biz?.name ?? l.appName, size: 48),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(biz?.name ?? l.appName, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text('${l.plan}: ${usage.planCode}', style: t.textTheme.bodySmall),
                ])),
                const Icon(Icons.workspace_premium_outlined),
              ]),
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(value: usage.maxEmployees <= 0 ? 0 : (usage.employees / usage.maxEmployees).clamp(0, 1).toDouble(), minHeight: 8),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(l.planUsage(usage.employees, usage.maxEmployees), style: t.textTheme.bodySmall),
            ]),
          ),
        const SizedBox(height: AppSpacing.lg),
        SettingsGroup(title: l.groupBusiness, children: [
          tile(Icons.rocket_launch_outlined, l.setupNav, '/more/setup'),
          tile(Icons.storefront_outlined, l.branches, '/more/branches'),
          tile(Icons.content_cut_rounded, l.services, '/more/services'),
          tile(Icons.badge_outlined, l.employees, '/more/employees'),
        ]),
        const SizedBox(height: AppSpacing.lg),
        SettingsGroup(title: l.groupSales, children: [
          tile(Icons.star_outline_rounded, l.reviewsNav, '/more/reviews'),
          tile(Icons.sell_outlined, l.promosNav, '/more/promos'),
          tile(Icons.undo_rounded, l.refundsNav, '/more/refunds'),
          tile(Icons.card_giftcard_rounded, l.giftCardsNav, '/more/gift-cards'),
        ]),
        const SizedBox(height: AppSpacing.lg),
        SettingsGroup(title: l.groupAccount, children: [
          tile(Icons.sms_outlined, l.messagesNav, '/more/messages'),
          tile(Icons.support_agent_outlined, l.supportNav, '/more/support'),
          tile(Icons.lock_outline_rounded, l.accountNav, '/more/account'),
        ]),
        const SizedBox(height: AppSpacing.lg),
        SettingsGroup(title: l.preferencesTitle, children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.language, style: t.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [for (final e in _names.entries) ButtonSegment(value: e.key, label: Text(e.value, maxLines: 1, overflow: TextOverflow.ellipsis))],
                  selected: {current},
                  onSelectionChanged: (s) => ref.read(settingsProvider.notifier).setLocale(Locale(s.first)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(l.theme, style: t.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: ThemeMode.system, label: Text(l.themeSystem, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ButtonSegment(value: ThemeMode.light, label: Text(l.themeLight, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ButtonSegment(value: ThemeMode.dark, label: Text(l.themeDark, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (s) => ref.read(settingsProvider.notifier).setThemeMode(s.first),
                ),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: AppSpacing.lg),
        SecondaryButton(label: l.logout, icon: Icons.logout_rounded, destructive: true, onPressed: () => ref.read(authControllerProvider.notifier).logout()),
      ]),
    );
  }
}
