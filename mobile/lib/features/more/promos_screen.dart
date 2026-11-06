import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/models.dart';
import '../../core/data/repository.dart';
import '../../core/design/tokens.dart';
import '../../core/errors.dart';
import '../../core/widgets/common.dart';
import '../../l10n/gen/app_localizations.dart';
import '../setup/setup_common.dart';

/// Promo codes: guests enter them on the public booking page, staff in the new-booking form. The server computes the discount
/// and the deposit on the discounted price; this screen only manages the codes.
class PromosScreen extends ConsumerWidget {
  const PromosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final res = ref.watch(promosProvider);
    final currency = ref.watch(currentBusinessProvider).value?.currency ?? 'KZT';
    return Scaffold(
      appBar: AppBar(title: Text(l.promosNav)),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('addPromo'), icon: const Icon(Icons.add), label: Text(l.promoAdd),
        onPressed: () => showDialog(context: context, builder: (_) => const _AddPromoDialog()),
      ),
      body: res.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(promosProvider)),
        data: (list) => list.isEmpty
            ? EmptyState(icon: Icons.sell_outlined, text: l.promosNone)
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, i) => _PromoTile(promo: list[i], currency: currency),
              ),
      ),
    );
  }
}

class _PromoTile extends ConsumerWidget {
  final PromoItem promo;
  final String currency;
  const _PromoTile({required this.promo, required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final value = promo.kind == 'PERCENT' ? '${promo.value.toStringAsFixed(promo.value == promo.value.roundToDouble() ? 0 : 2)}%' : money(context, promo.value, currency);
    final parts = [
      l.promoDiscountOf(value),
      l.promoUsed('${promo.usedCount}', promo.maxUses == null ? '' : ' / ${promo.maxUses}'),
      if (promo.validUntil != null) l.promoValidUntilLabel(DateFormat('dd.MM.yyyy').format(DateTime.parse(promo.validUntil!))),
    ];
    return Card(
      child: SwitchListTile(
        key: Key('promo-${promo.code}'),
        title: Text(promo.code, style: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 1)),
        subtitle: Text(parts.join(' · ')),
        value: promo.active,
        onChanged: (v) async {
          try {
            await setPromoActive(ref, promo.id, v);
          } catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(context, e)), behavior: SnackBarBehavior.floating));
          }
        },
      ),
    );
  }
}

class _AddPromoDialog extends ConsumerStatefulWidget {
  const _AddPromoDialog();
  @override
  ConsumerState<_AddPromoDialog> createState() => _AddPromoState();
}

class _AddPromoState extends ConsumerState<_AddPromoDialog> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _value = TextEditingController();
  final _max = TextEditingController();
  String _kind = 'PERCENT';
  DateTime? _until;
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.promoAdd),
      content: SingleChildScrollView(
        child: Form(key: _form, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextFormField(
            key: const Key('promoCode'), controller: _code, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(labelText: l.promoCode),
            validator: (v) => v == null || !RegExp(r'^[A-Za-z0-9_-]{3,32}$').hasMatch(v.trim()) ? l.validationRequired : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<String>(
            segments: [ButtonSegment(value: 'PERCENT', label: Text(l.promoKindPercent)), ButtonSegment(value: 'FIXED', label: Text(l.promoKindFixed))],
            selected: {_kind}, onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          TextFormField(
            key: const Key('promoValue'), controller: _value, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: l.promoValue),
            validator: (v) {
              final n = double.tryParse((v ?? '').replaceAll(',', '.'));
              if (n == null || n <= 0 || (_kind == 'PERCENT' && n > 100)) return l.validationRequired;
              return null;
            },
          ),
          TextFormField(
            key: const Key('promoMax'), controller: _max, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l.promoMaxUses),
            validator: (v) => v == null || v.trim().isEmpty || (int.tryParse(v.trim()) ?? 0) > 0 ? null : l.validationRequired,
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            key: const Key('promoUntil'), icon: const Icon(Icons.event), label: Text(_until == null ? l.promoUntil : DateFormat('dd.MM.yyyy').format(_until!)),
            onPressed: () async {
              final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730)));
              if (d != null && mounted) setState(() => _until = d);
            },
          ),
          FormError(_error),
        ])),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          key: const Key('savePromo'),
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: _busy ? null : () async {
            if (!_form.currentState!.validate()) return;
            setState(() { _busy = true; _error = null; });
            final err = await attempt(context, () => createPromo(ref, {
                  'code': _code.text.trim(), 'kind': _kind, 'value': _value.text.trim().replaceAll(',', '.'),
                  'maxUses': _max.text.trim().isEmpty ? null : int.parse(_max.text.trim()),
                  'validUntil': _until == null ? null : DateFormat('yyyy-MM-dd').format(_until!),
                }));
            if (!context.mounted) return;
            if (err == null) { Navigator.pop(context); } else { setState(() { _busy = false; _error = err; }); }
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}
