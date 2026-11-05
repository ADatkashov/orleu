import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/models.dart';
import '../../core/data/repository.dart';
import '../../core/design/tokens.dart';
import '../../core/widgets/common.dart';
import '../../l10n/gen/app_localizations.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final biz = ref.watch(currentBusinessProvider).value;
    final name = ref.watch(meNameProvider).value ?? '';
    final today = dayStart(DateTime.now());
    final bookings = ref.watch(bookingsProvider(today));
    final summary = ref.watch(todaySummaryProvider);
    final currency = biz?.currency ?? 'KZT';

    Future<void> refresh() async {
      ref.invalidate(bookingsProvider);
      ref.invalidate(todaySummaryProvider);
      await ref.read(bookingsProvider(today).future);
    }

    return Scaffold(
      appBar: AppBar(title: Text(biz?.name ?? l.appName)),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
          Text(l.greeting(name.split(' ').first), style: t.textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.md),
          summary.when(
            loading: () => const SizedBox(height: 96, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(todaySummaryProvider)),
            data: (s) => Column(children: [
              Row(children: [
                Expanded(child: StatTile(label: l.todayCollected, value: money(context, s.netCollected, currency))),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: StatTile(label: l.todayBookings, value: '${s.totalBookings}')),
              ]),
            ]),
          ),
          const SizedBox(height: AppSpacing.lg),
          bookings.when(
            loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(bookingsProvider)),
            data: (list) {
              final pending = list.where((b) => b.needsAction).length;
              final upcoming = list.where((b) => b.isLive && b.endsAt.isAfter(DateTime.now())).take(5).toList();
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                StatTile(label: l.pendingBookings, value: '$pending', valueColor: pending > 0 ? AppColors.warning : null),
                const SizedBox(height: AppSpacing.lg),
                Text(l.upcoming, style: t.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                if (upcoming.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: AppSpacing.md), child: Text(l.nothingUpcoming, style: t.textTheme.bodySmall))
                else for (final b in upcoming) Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: _Row(b)),
              ]);
            },
          ),
        ]),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final Booking b;
  const _Row(this.b);
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      child: ListTile(
        title: Text('${DateFormat.Hm().format(b.startsAt)}  ${b.serviceName}', style: t.textTheme.titleMedium),
        subtitle: Text('${b.customerName} · ${b.employeeName}'),
        trailing: StatusChip(b.status),
      ),
    );
  }
}
