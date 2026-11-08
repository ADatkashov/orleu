import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/repository.dart';
import '../../core/design/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../l10n/gen/app_localizations.dart';
import '../setup/setup_common.dart';

/// Refund approval: the owner/admin sets the threshold above which refunds wait for approval and decides the pending requests.
/// Everyone with finance access sees the list; only approvers get the buttons (the server enforces it either way).
class RefundsScreen extends ConsumerWidget {
  const RefundsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final role = ref.watch(myRoleProvider).value;
    final approver = canApproveRefund(role);
    final res = ref.watch(refundRequestsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.refundsNav)),
      body: res.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(refundRequestsProvider)),
        data: (list) => ListView(padding: EdgeInsets.fromLTRB(AppSpacing.gutter(context), AppSpacing.sm, AppSpacing.gutter(context), AppSpacing.xl), children: [
          const _PolicyCard(),
          const SizedBox(height: AppSpacing.md),
          if (list.isEmpty) EmptyState(icon: Icons.undo, text: l.refundsNone, key: const Key('noRefunds')),
          for (final r in list) Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(money(context, r.amount, r.currency), key: Key('refund-${r.id}'), style: Theme.of(context).textTheme.titleMedium)),
                  StatusBadge(r.pending ? l.refundStatusPending : r.status == 'APPROVED' ? l.refundStatusApproved : l.refundStatusRejected, tone: r.pending ? BadgeTone.warning : r.status == 'APPROVED' ? BadgeTone.success : BadgeTone.danger),
                ]),
                if (r.requestedByName != null) Text(l.refundRequestedBy(r.requestedByName!), style: Theme.of(context).textTheme.bodySmall),
                if (r.decisionNote != null) Text(r.decisionNote!, style: Theme.of(context).textTheme.bodySmall),
                if (r.pending && approver) Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Row(children: [
                    FilledButton(key: Key('approve-${r.id}'), style: FilledButton.styleFrom(minimumSize: const Size(96, 44)), onPressed: () => guarded(context, () => decideRefund(ref, r.id, approve: true)), child: Text(l.refundApprove)),
                    const SizedBox(width: AppSpacing.sm),
                    OutlinedButton(key: Key('reject-${r.id}'), style: OutlinedButton.styleFrom(minimumSize: const Size(96, 44), foregroundColor: context.palette.dangerFg), onPressed: () => guarded(context, () => decideRefund(ref, r.id, approve: false)), child: Text(l.refundReject)),
                  ]),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _PolicyCard extends ConsumerStatefulWidget {
  const _PolicyCard();
  @override
  ConsumerState<_PolicyCard> createState() => _PolicyState();
}

class _PolicyState extends ConsumerState<_PolicyCard> {
  final _text = TextEditingController();
  bool _loaded = false, _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final role = ref.watch(myRoleProvider).value;
    final policy = ref.watch(refundPolicyProvider);
    final cur = ref.watch(currentBusinessProvider).value?.currency ?? 'KZT';
    return AppCard(
      child: policy.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text(l.errNetwork),
        data: (t) {
          if (!_loaded) { _text.text = t == null ? '' : (t == t.roundToDouble() ? t.toStringAsFixed(0) : t.toStringAsFixed(2)); _loaded = true; }
          final canEdit = role == 'BUSINESS_OWNER' || role == 'BUSINESS_ADMIN';
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.refundsPolicyTitle, style: Theme.of(context).textTheme.titleMedium),
            Text(t == null ? l.refundsPolicyOff : l.refundsPolicyOn(money(context, t, cur)), key: const Key('policyState'), style: Theme.of(context).textTheme.bodySmall),
            if (canEdit) ...[
              const SizedBox(height: AppSpacing.sm),
              TextField(key: const Key('policyThreshold'), controller: _text, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: l.refundsThreshold, suffixText: cur, helperText: l.refundsThresholdHint)),
              FormError(_error),
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                key: const Key('savePolicy'),
                onPressed: _busy ? null : () async {
                  final raw = _text.text.trim().replaceAll(',', '.');
                  final v = raw.isEmpty ? null : double.tryParse(raw);
                  if (raw.isNotEmpty && (v == null || v < 0)) { setState(() => _error = l.validationAmount); return; }
                  setState(() { _busy = true; _error = null; });
                  final err = await attempt(context, () => setRefundPolicy(ref, v));
                  if (!mounted) return;
                  setState(() { _busy = false; _error = err; });
                },
                child: Text(l.save),
              ),
            ],
          ]);
        },
      ),
    );
  }
}
