import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/data/repository.dart';
import '../../core/design/tokens.dart';
import '../../core/widgets/common.dart';
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

    Widget step(bool done, String title, String route) => Card(
          child: ListTile(
            leading: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? AppColors.success : t.colorScheme.outline),
            title: Text(title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(route),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l.setupTitle)),
      body: ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
        Text(l.setupIntro, style: t.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.md),
        step(hasBranch, l.stepBranch, '/more/branches'),
        const SizedBox(height: AppSpacing.sm),
        step(hasHours, l.stepHours, '/more/branches'),
        const SizedBox(height: AppSpacing.sm),
        step(hasService, l.stepService, '/more/services'),
        const SizedBox(height: AppSpacing.sm),
        step(hasEmployee, l.stepEmployee, '/more/employees'),
        const SizedBox(height: AppSpacing.lg),
        Text(l.stepPublish, style: t.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (biz.published) ...[
          Card(child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Icon(Icons.public, color: AppColors.success), const SizedBox(width: 8), Expanded(child: Text(l.publishedHint, style: t.textTheme.titleMedium))]),
            const SizedBox(height: AppSpacing.sm),
            Text(l.bookingLink, style: t.textTheme.bodySmall),
            SelectableText(link, key: const Key('bookingLink')),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy), label: Text(l.copyLink),
              onPressed: () async {
                final m = ScaffoldMessenger.of(context);
                await Clipboard.setData(ClipboardData(text: link));
                m.showSnackBar(SnackBar(content: Text(l.copied), behavior: SnackBarBehavior.floating));
              },
            ),
          ]))),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(onPressed: () => guarded(context, () => ref.read(bookingActionsProvider).setPublished(false)), child: Text(l.unpublish)),
        ] else
          FilledButton(
            key: const Key('publish'),
            // always enabled: the server is the authority on readiness and explains what is missing
            onPressed: () => guarded(context, () => ref.read(bookingActionsProvider).setPublished(true)),
            child: Text(l.publish),
          ),
        if (!biz.published && !ready) Padding(padding: const EdgeInsets.only(top: AppSpacing.sm), child: Text(l.errNotReady, style: t.textTheme.bodySmall)),
      ]),
    );
  }
}
