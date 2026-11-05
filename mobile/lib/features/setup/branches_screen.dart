import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/models.dart';
import '../../core/data/repository.dart';
import '../../core/design/tokens.dart';
import '../../core/widgets/common.dart';
import '../../l10n/gen/app_localizations.dart';
import 'setup_common.dart';

class BranchesScreen extends ConsumerWidget {
  const BranchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final res = ref.watch(branchesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.branches)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add), label: Text(l.addBranch),
        onPressed: () => showDialog(context: context, builder: (_) => const _AddBranchDialog()),
      ),
      body: res.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(branchesProvider)),
        data: (list) => list.isEmpty
            ? EmptyState(icon: Icons.storefront_outlined, text: l.noneYet)
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, i) {
                  final b = list[i];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.storefront_outlined),
                      key: Key('branch-${b.id}'),
                      title: Text(b.name, style: b.active ? null : TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      subtitle: Text(!b.active ? l.inactive : b.hours.isEmpty ? l.stepHours : (b.address ?? l.workingHours)),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(key: Key('editBranch-${b.id}'), tooltip: l.edit, icon: const Icon(Icons.edit_outlined), onPressed: () => showDialog(context: context, builder: (_) => _AddBranchDialog(initial: b))),
                        Icon(b.hours.isEmpty ? Icons.warning_amber_rounded : Icons.schedule, color: b.hours.isEmpty ? AppColors.warning : null),
                      ]),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HoursScreen(branch: b))),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _AddBranchDialog extends ConsumerStatefulWidget {
  final Branch? initial; // null = create, otherwise edit
  const _AddBranchDialog({this.initial});
  @override
  ConsumerState<_AddBranchDialog> createState() => _AddBranchState();
}

class _AddBranchState extends ConsumerState<_AddBranchDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name ?? ''), _address = TextEditingController(text: widget.initial?.address ?? '');
  late bool _active = widget.initial?.active ?? true;
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.initial == null ? l.addBranch : l.editLocation),
      content: Form(
        key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: _name, decoration: InputDecoration(labelText: l.branchName), validator: (v) => v == null || v.trim().isEmpty ? l.validationRequired : null),
          const SizedBox(height: AppSpacing.md),
          TextFormField(controller: _address, decoration: InputDecoration(labelText: l.address)),
          if (widget.initial != null) SwitchListTile(key: const Key('branchActive'), contentPadding: EdgeInsets.zero, title: Text(l.active), subtitle: Text(l.deactivateNote), value: _active, onChanged: (v) => setState(() => _active = v)),
          FormError(_error),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: _busy ? null : () async {
            if (!_form.currentState!.validate()) return;
            setState(() => _busy = true);
            final actions = ref.read(bookingActionsProvider);
            final err = await attempt(context, () => widget.initial == null
                ? actions.createBranch(_name.text.trim(), _address.text.trim())
                : actions.updateBranch(widget.initial!.id, name: _name.text.trim(), address: _address.text.trim(), active: _active));
            if (!context.mounted) return;
            if (err == null) { Navigator.pop(context); } else { setState(() { _busy = false; _error = err; }); }
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}

class HoursScreen extends ConsumerStatefulWidget {
  final Branch branch;
  const HoursScreen({super.key, required this.branch});
  @override
  ConsumerState<HoursScreen> createState() => _HoursState();
}

/// Compact so a whole row (day, two times, switch) fits 320px-wide phones.
final _compact = TextButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 8), tapTargetSize: MaterialTapTargetSize.padded);

class _HoursState extends ConsumerState<HoursScreen> {
  late final Map<int, (String, String)> _hours = Map.of(widget.branch.hours);
  bool _busy = false;

  Future<void> _pick(int day, bool open) async {
    final cur = _hours[day]!;
    final t = await showTimePicker(context: context, initialTime: parseHhmm(open ? cur.$1 : cur.$2));
    if (t == null) return;
    setState(() => _hours[day] = open ? (hhmm(t), cur.$2) : (cur.$1, hhmm(t)));
  }

  bool get _valid => _hours.values.every((h) => h.$2.compareTo(h.$1) > 0);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.branch.name)),
      body: ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
        Text(l.workingHours, style: t.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          key: const Key('applyDefaultHours'),
          onPressed: () => setState(() { for (var d = 1; d <= 7; d++) { _hours[d] = ('09:00', '18:00'); } }),
          child: Text(l.applyDefaultHours),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var d = 1; d <= 7; d++) Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            child: Row(children: [
              SizedBox(width: 40, child: Text(weekdayLabel(context, d), style: t.textTheme.titleMedium)),
              Expanded(child: _hours.containsKey(d)
                  // Wrap: on very narrow screens or large text sizes the times flow to a second line instead of overflowing
                  ? Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                      TextButton(key: Key('open$d'), style: _compact, onPressed: () => _pick(d, true), child: Text(_hours[d]!.$1)),
                      const Text('–'),
                      TextButton(key: Key('close$d'), style: _compact, onPressed: () => _pick(d, false), child: Text(_hours[d]!.$2)),
                    ])
                  : Text(l.closed, style: t.textTheme.bodySmall)),
              Switch(key: Key('day$d'), value: _hours.containsKey(d), onChanged: (on) => setState(() { on ? _hours[d] = ('09:00', '18:00') : _hours.remove(d); })),
            ]),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          key: const Key('saveHours'),
          onPressed: _busy || !_valid ? null : () async {
            setState(() => _busy = true);
            final ok = await guarded(context, () => ref.read(bookingActionsProvider).setHours(widget.branch.id, _hours));
            if (!context.mounted) return;
            setState(() => _busy = false);
            if (ok) Navigator.of(context).pop();
          },
          child: Text(l.save),
        ),
      ]),
    );
  }
}
