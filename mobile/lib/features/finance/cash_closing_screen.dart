import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/repository.dart';
import '../../core/design/tokens.dart';
import '../../core/tz.dart';
import '../../core/widgets/widgets.dart';
import '../../l10n/gen/app_localizations.dart';
import '../setup/setup_common.dart';

/// Cash register closing: the system shows what the ledger says should be in the drawer since the last closing, staff enter what they counted,
/// and the difference is recorded for good. Bank and card amounts are shown for the accountant; they are not counted physically.
class CashClosingScreen extends ConsumerStatefulWidget {
  const CashClosingScreen({super.key});
  @override
  ConsumerState<CashClosingScreen> createState() => _State();
}

class _State extends ConsumerState<CashClosingScreen> {
  final _counted = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  double? get _countedValue => double.tryParse(_counted.text.trim().replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final zone = ref.watch(businessZoneProvider);
    final cur = ref.watch(currentBusinessProvider).value?.currency ?? 'KZT';
    final locale = Localizations.localeOf(context).toLanguageTag();
    final fmt = DateFormat.yMMMd(locale).add_Hm();
    final preview = ref.watch(cashPreviewProvider);
    final history = ref.watch(cashClosingsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.closingTitle)),
      body: preview.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(cashPreviewProvider)),
        data: (p) {
          final counted = _countedValue;
          final diff = counted == null ? null : counted - p.cash.net;
          return ListView(padding: EdgeInsets.fromLTRB(AppSpacing.gutter(context), AppSpacing.sm, AppSpacing.gutter(context), AppSpacing.xl), children: [
            // at the top: the preview reloads after an error and the list scrolls back up, so a message below the fold would be missed
            FormError(_error),
            Text(l.closingPeriod(fmt.format(wallFromInstant(p.periodStart, zone)), fmt.format(wallFromInstant(p.periodEnd, zone))), style: t.textTheme.bodySmall),
            if (p.firstClosing) Text(l.closingFirst, key: const Key('closingFirst'), style: t.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            StatCard(icon: Icons.point_of_sale_outlined, label: l.closingExpectedCash, value: money(context, p.cash.net, cur), hero: true),
            const SizedBox(height: AppSpacing.sm + 2),
            Row(children: [
              Expanded(child: StatTile(label: l.methodBank, value: money(context, p.bank.net, cur))),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(child: StatTile(label: l.methodCard, value: money(context, p.card.net, cur))),
            ]),
            const SizedBox(height: AppSpacing.xs),
            Text(l.closingNotCounted, style: t.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('countedCash'), controller: _counted, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l.closingCounted, suffixText: cur), onChanged: (_) => setState(() {}),
            ),
            if (diff != null) Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Align(
                alignment: Alignment.centerLeft,
                child: StatusBadge(
                  diff == 0 ? l.closingMatches : diff < 0 ? l.closingShortage(money(context, -diff, cur)) : l.closingSurplus(money(context, diff, cur)),
                  key: const Key('closingDiff'), tone: diff == 0 ? BadgeTone.success : BadgeTone.warning,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(key: const Key('closingNote'), controller: _note, maxLength: 500, decoration: InputDecoration(labelText: l.notes)),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              key: const Key('confirmClosing'),
              onPressed: _busy || counted == null || counted < 0 ? null : () async {
                final messenger = ScaffoldMessenger.of(context);
                setState(() { _busy = true; _error = null; });
                final err = await attempt(context, () => closeCash(ref, expectedCash: p.cash.net.toStringAsFixed(2), countedCash: counted.toStringAsFixed(2), note: _note.text));
                if (!mounted) return;
                if (err == null) {
                  _counted.clear();
                  _note.clear();
                  setState(() => _busy = false);
                  messenger.showSnackBar(SnackBar(content: Text(l.closingDone)));
                } else {
                  ref.invalidate(cashPreviewProvider); // show the new expected figure before they confirm again
                  setState(() { _busy = false; _error = err; });
                }
              },
              child: Text(l.closingConfirm),
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(l.closingHistory),
            const SizedBox(height: AppSpacing.sm + 4),
            history.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(l.errNetwork),
              data: (list) => list.isEmpty
                  ? Text(l.closingNone, key: const Key('noClosings'), style: t.textTheme.bodySmall)
                  : Column(children: [
                      for (final c in list) Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: AppCard(padding: EdgeInsets.zero, child: ListTile(
                        key: Key('closing-${c.id}'),
                        title: Text(fmt.format(wallFromInstant(c.periodEnd, zone))),
                        subtitle: Text([
                          l.closingRow(money(context, c.expectedCash, c.currency), money(context, c.countedCash, c.currency)),
                          if (c.closedByName != null) c.closedByName!,
                          if (c.note != null) c.note!,
                        ].join(' · ')),
                        trailing: Text(c.difference == 0 ? '0' : (c.difference > 0 ? '+' : '−') + money(context, c.difference.abs(), c.currency),
                            style: TextStyle(color: c.difference == 0 ? context.palette.successFg : context.palette.warningFg, fontWeight: FontWeight.w700)),
                      ))),
                    ]),
            ),
          ]);
        },
      ),
    );
  }
}
