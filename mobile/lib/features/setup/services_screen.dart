import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/repository.dart';
import '../../core/design/tokens.dart';
import '../../core/widgets/common.dart';
import '../../l10n/gen/app_localizations.dart';
import 'setup_common.dart';

class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cur = ref.watch(currentBusinessProvider).value?.currency ?? 'KZT';
    final res = ref.watch(servicesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.services)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add), label: Text(l.addService),
        onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => const _ServiceForm()),
      ),
      body: res.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(servicesProvider)),
        data: (list) => list.isEmpty
            ? EmptyState(icon: Icons.content_cut, text: l.noneYet)
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, i) => Card(
                  child: ListTile(
                    title: Text(list[i].name),
                    subtitle: Text('${list[i].durationMinutes} ${l.minutesShort}'),
                    trailing: Text(money(context, list[i].price, cur), style: Theme.of(context).textTheme.titleMedium),
                  ),
                ),
              ),
      ),
    );
  }
}

class _ServiceForm extends ConsumerStatefulWidget {
  const _ServiceForm();
  @override
  ConsumerState<_ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends ConsumerState<_ServiceForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _duration = TextEditingController(text: '60'), _price = TextEditingController(),
      _deposit = TextEditingController(), _buffer = TextEditingController();
  bool _busy = false;

  static final _money = RegExp(r'^\d{1,12}([.,]\d{1,2})?$');

  String? _intIn(String? v, AppLocalizations l, int min, int max, {bool optional = false}) {
    if ((v == null || v.isEmpty) && optional) return null;
    final n = int.tryParse(v ?? '');
    return n == null || n < min || n > max ? l.validationRequired : null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(l.addService, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            TextFormField(key: const Key('svcName'), controller: _name, decoration: InputDecoration(labelText: l.serviceName), validator: (v) => v == null || v.trim().isEmpty ? l.validationRequired : null),
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              Expanded(child: TextFormField(key: const Key('svcDuration'), controller: _duration, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l.durationMin), validator: (v) => _intIn(v, l, 5, 1440))),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: TextFormField(key: const Key('svcPrice'), controller: _price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: l.priceField),
                  validator: (v) => v == null || !_money.hasMatch(v.trim()) ? l.validationRequired : null)),
            ]),
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              Expanded(child: TextFormField(key: const Key('svcDeposit'), controller: _deposit, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l.depositPercentOptional), validator: (v) => _intIn(v, l, 0, 100, optional: true))),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: TextFormField(key: const Key('svcBuffer'), controller: _buffer, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l.bufferMin), validator: (v) => _intIn(v, l, 0, 240, optional: true))),
            ]),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: const Key('svcSave'),
              onPressed: _busy ? null : () async {
                if (!_form.currentState!.validate()) return;
                setState(() => _busy = true);
                final ok = await guarded(context, () => ref.read(bookingActionsProvider).createService(
                      name: _name.text.trim(), durationMinutes: int.parse(_duration.text), price: _price.text.trim().replaceAll(',', '.'),
                      depositPercent: _deposit.text.isEmpty ? null : _deposit.text, bufferMinutes: _buffer.text.isEmpty ? null : int.parse(_buffer.text)));
                if (!context.mounted) return;
                if (ok) { Navigator.pop(context); } else { setState(() => _busy = false); }
              },
              child: Text(l.save),
            ),
          ]),
        ),
      ),
    );
  }
}
