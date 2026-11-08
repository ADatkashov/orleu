import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/models.dart';
import '../../core/data/repository.dart';
import '../../core/design/tokens.dart';
import '../../core/widgets/common.dart';
import '../../l10n/gen/app_localizations.dart';
import '../setup/setup_common.dart';

/// Gift cards: sell (the code is shown once), see balances, void. Redeeming happens on the booking (Pay with gift card).
class GiftCardsScreen extends ConsumerWidget {
  const GiftCardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final role = ref.watch(myRoleProvider).value;
    final res = ref.watch(giftCardsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.giftCardsNav)),
      floatingActionButton: canCloseCash(role)
          ? FloatingActionButton.extended(key: const Key('sellGiftCard'), icon: const Icon(Icons.card_giftcard), label: Text(l.giftSell), onPressed: () => showDialog(context: context, builder: (_) => const _SellDialog()))
          : null,
      body: res.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(giftCardsProvider)),
        data: (list) => list.isEmpty
            ? EmptyState(icon: Icons.card_giftcard, text: l.giftNone)
            : ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96), children: [
                Text(l.giftNote, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: AppSpacing.sm),
                for (final c in list) Card(child: ListTile(
                  key: Key('card-${c.id}'),
                  leading: const Icon(Icons.card_giftcard),
                  title: Text('•••• ${c.codeLast4}'),
                  subtitle: Text(['${money(context, c.balance, c.currency)} / ${money(context, c.initialAmount, c.currency)}', if (c.buyerName != null) c.buyerName!].join(' · ')),
                  trailing: c.status == 'VOID'
                      ? Chip(label: Text(l.giftVoid))
                      : c.expired
                          ? Chip(label: Text(l.giftExpired))
                          : canApproveRefund(role)
                              ? TextButton(key: Key('void-${c.id}'), onPressed: () => showDialog(context: context, builder: (_) => _VoidDialog(card: c)), child: Text(l.giftVoidAction))
                              : null,
                )),
              ]),
      ),
    );
  }
}

class _VoidDialog extends ConsumerWidget {
  final GiftCard card;
  const _VoidDialog({required this.card});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.giftVoidAction),
      content: Text(l.giftVoidWarning('•••• ${card.codeLast4}')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(key: const Key('confirmVoid'), style: FilledButton.styleFrom(backgroundColor: context.palette.dangerSolid, foregroundColor: context.palette.onDangerSolid, minimumSize: const Size(96, 44)),
            onPressed: () { Navigator.pop(context); guarded(context, () => voidGiftCard(ref, card.id)); }, child: Text(l.giftVoidAction)),
      ],
    );
  }
}

class _SellDialog extends ConsumerStatefulWidget {
  const _SellDialog();
  @override
  ConsumerState<_SellDialog> createState() => _SellState();
}

class _SellState extends ConsumerState<_SellDialog> {
  final _amount = TextEditingController();
  final _buyer = TextEditingController();
  final String _key = newIdempotencyKey();
  String _method = 'CASH';
  bool _busy = false;
  String? _error, _code;
  bool _lost = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_code != null || _lost) {
      return AlertDialog(
        title: Text(l.giftSell),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_code != null) ...[
            Text(l.giftCodeOnce),
            const SizedBox(height: AppSpacing.sm),
            SelectableText(_code!, key: const Key('giftCode'), style: Theme.of(context).textTheme.headlineSmall),
          ] else
            Text(l.giftCodeLost, key: const Key('giftCodeLost')),
        ]),
        actions: [
          if (_code != null) TextButton(key: const Key('copyCode'), onPressed: () => Clipboard.setData(ClipboardData(text: _code!)), child: Text(l.giftCopy)),
          FilledButton(key: const Key('doneSell'), style: FilledButton.styleFrom(minimumSize: const Size(96, 44)), onPressed: () => Navigator.pop(context), child: Text(l.close)),
        ],
      );
    }
    final methods = {'CASH': l.methodCash, 'BANK_TRANSFER': l.methodBank, 'CARD_MANUAL': l.methodCard};
    return AlertDialog(
      title: Text(l.giftSell),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(key: const Key('giftAmount'), controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: l.paymentAmount)),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(key: const Key('giftMethod'), initialValue: _method, decoration: InputDecoration(labelText: l.paymentMethod),
            items: [for (final e in methods.entries) DropdownMenuItem(value: e.key, child: Text(e.value))], onChanged: (v) => setState(() => _method = v ?? _method)),
        const SizedBox(height: AppSpacing.sm),
        TextField(key: const Key('giftBuyer'), controller: _buyer, decoration: InputDecoration(labelText: l.giftBuyer)),
        FormError(_error),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          key: const Key('confirmSell'), style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: _busy ? null : () async {
            final v = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
            if (v == null || v <= 0) { setState(() => _error = l.validationAmount); return; }
            setState(() { _busy = true; _error = null; });
            String? code;
            final err = await attempt(context, () async { code = await sellGiftCard(ref, amount: _amount.text.trim().replaceAll(',', '.'), method: _method, buyerName: _buyer.text, idempotencyKey: _key); });
            if (!mounted) return;
            setState(() { _busy = false; _error = err; if (err == null) { _code = code; _lost = code == null; } });
          },
          child: Text(l.giftSell),
        ),
      ],
    );
  }
}
