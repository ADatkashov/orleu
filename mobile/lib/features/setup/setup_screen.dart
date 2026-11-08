import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/data/repository.dart';
import '../../core/design/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../l10n/gen/app_localizations.dart';
import 'setup_common.dart';

const publicBaseUrl = String.fromEnvironment('ORLEU_PUBLIC_URL', defaultValue: apiBaseUrl);

/// Onboarding checklist computed from backend data (nothing is stored client-side).
class SetupScreen extends ConsumerWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final biz = ref.watch(currentBusinessProvider).value;
    final branches = ref.watch(branchesProvider);
    final services = ref.watch(servicesProvider);
    final employees = ref.watch(employeesProvider);

    final firstError = [branches, services, employees].where((a) => a.hasError).firstOrNull;
    if (firstError != null) {
      return Scaffold(appBar: AppBar(title: Text(l.setupTitle)), body: ErrorRetry(error: firstError.error!, onRetry: () {
        ref.invalidate(branchesProvider); ref.invalidate(servicesProvider); ref.invalidate(employeesProvider);
      }));
    }
    if (biz == null || !branches.hasValue || !services.hasValue || !employees.hasValue) {
      return Scaffold(appBar: AppBar(title: Text(l.setupTitle)), body: const SkeletonList());
    }

    final hasBranch = branches.value!.any((b) => b.active);
    final hasHours = branches.value!.any((b) => b.active && b.hours.isNotEmpty);
    final hasService = services.value!.any((s) => s.active);
    final hasEmployee = employees.value!.any((e) => e.active && e.branchIds.isNotEmpty && e.serviceIds.isNotEmpty);
    final ready = hasBranch && hasHours && hasService && hasEmployee;
    final link = '$publicBaseUrl/b/${biz.slug}';

    Widget step(bool done, String title, String route, int n) => AppCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
          onTap: () => context.push(route),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Row(children: [
              Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, size: AppIconSize.lg, color: done ? context.palette.success : t.colorScheme.outline),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(title, style: t.textTheme.titleSmall?.copyWith(fontSize: 15, decoration: done ? TextDecoration.none : null))),
              Icon(Icons.chevron_right_rounded, color: t.colorScheme.onSurfaceVariant),
            ]),
          ),
        );

    final doneCount = [hasBranch, hasHours, hasService, hasEmployee].where((d) => d).length;
    return Scaffold(
      appBar: AppBar(title: Text(l.setupTitle)),
      body: ListView(padding: EdgeInsets.fromLTRB(AppSpacing.gutter(context), AppSpacing.sm, AppSpacing.gutter(context), AppSpacing.xl), children: [
        AppCard(
          gradient: AppGradients.heroOf(context), elevated: true, radius: AppRadius.hero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.setupIntro, style: t.textTheme.bodyMedium?.copyWith(color: context.palette.onHero)),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(value: doneCount / 4, minHeight: 8, color: context.palette.heroAccent, backgroundColor: Colors.white.withValues(alpha: 0.18)),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(l.setupProgress(doneCount, 4), style: t.textTheme.labelLarge?.copyWith(color: context.palette.onHeroMuted)),
          ]),
        ),
        const SizedBox(height: AppSpacing.md),
        step(hasBranch, l.stepBranch, '/more/branches', 1),
        const SizedBox(height: AppSpacing.sm),
        step(hasHours, l.stepHours, '/more/branches', 2),
        const SizedBox(height: AppSpacing.sm),
        step(hasService, l.stepService, '/more/services', 3),
        const SizedBox(height: AppSpacing.sm),
        step(hasEmployee, l.stepEmployee, '/more/employees', 4),
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(l.stepPublish),
        const SizedBox(height: AppSpacing.sm + 4),
        if (biz.published) ...[
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(Icons.public, color: context.palette.success), const SizedBox(width: 8), Expanded(child: Text(l.publishedHint, style: t.textTheme.titleMedium))]),
            const SizedBox(height: AppSpacing.sm),
            Text(l.bookingLink, style: t.textTheme.bodySmall),
            SelectableText(link, key: const Key('bookingLink')),
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(
              icon: Icons.copy_rounded, label: l.copyLink,
              onPressed: () async {
                final m = ScaffoldMessenger.of(context);
                await Clipboard.setData(ClipboardData(text: link));
                m.showSnackBar(SnackBar(content: Text(l.copied), behavior: SnackBarBehavior.floating));
              },
            ),
          ])),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(label: l.unpublish, destructive: true, onPressed: () => guarded(context, () => ref.read(bookingActionsProvider).setPublished(false))),
        ] else
          PrimaryButton(
            key: const Key('publish'), label: l.publish,
            // always enabled: the server is the authority on readiness and explains what is missing
            onPressed: () => guarded(context, () => ref.read(bookingActionsProvider).setPublished(true)),
          ),
        if (!biz.published && !ready) Padding(padding: const EdgeInsets.only(top: AppSpacing.sm), child: Text(l.errNotReady, style: t.textTheme.bodySmall)),
      ]),
    );
  }
}
