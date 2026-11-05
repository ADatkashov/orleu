import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/models.dart';
import '../../core/data/repository.dart';
import '../../core/design/tokens.dart';
import '../../core/widgets/common.dart';
import '../../l10n/gen/app_localizations.dart';
import 'setup_common.dart';

class EmployeesScreen extends ConsumerWidget {
  const EmployeesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final res = ref.watch(employeesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.employees)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add_alt), label: Text(l.addEmployee),
        onPressed: () => showDialog(context: context, builder: (_) => const _AddEmployeeDialog()),
      ),
      body: res.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(employeesProvider)),
        data: (list) => list.isEmpty
            ? EmptyState(icon: Icons.badge_outlined, text: l.noneYet)
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, i) {
                  final e = list[i];
                  final assigned = e.branchIds.isNotEmpty && e.serviceIds.isNotEmpty;
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text(e.displayName.isEmpty ? '?' : e.displayName[0].toUpperCase())),
                      title: Text(e.displayName),
                      subtitle: Text('${l.services}: ${e.serviceIds.length} · ${l.branches}: ${e.branchIds.length}'),
                      trailing: Icon(assigned ? Icons.check_circle : Icons.warning_amber_rounded, color: assigned ? AppColors.success : AppColors.warning),
                      onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => AssignmentsSheet(employee: e)),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _AddEmployeeDialog extends ConsumerStatefulWidget {
  const _AddEmployeeDialog();
  @override
  ConsumerState<_AddEmployeeDialog> createState() => _AddEmployeeState();
}

class _AddEmployeeState extends ConsumerState<_AddEmployeeDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.addEmployee),
      content: Form(key: _form, child: TextFormField(key: const Key('empName'), controller: _name, decoration: InputDecoration(labelText: l.employeeName), validator: (v) => v == null || v.trim().isEmpty ? l.validationRequired : null)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: _busy ? null : () async {
            if (!_form.currentState!.validate()) return;
            setState(() => _busy = true);
            final ok = await guarded(context, () => ref.read(bookingActionsProvider).createEmployee(_name.text.trim()));
            if (!context.mounted) return;
            if (ok) { Navigator.pop(context); } else { setState(() => _busy = false); }
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}

class AssignmentsSheet extends ConsumerStatefulWidget {
  final Employee employee;
  const AssignmentsSheet({super.key, required this.employee});
  @override
  ConsumerState<AssignmentsSheet> createState() => _AssignmentsState();
}

class _AssignmentsState extends ConsumerState<AssignmentsSheet> {
  late final Set<String> _branches = widget.employee.branchIds.toSet();
  late final Set<String> _services = widget.employee.serviceIds.toSet();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final branches = ref.watch(branchesProvider).value ?? const <Branch>[];
    final services = ref.watch(servicesProvider).value ?? const <ServiceItem>[];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(widget.employee.displayName, style: t.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          Text(l.assignLocations, style: t.textTheme.titleMedium),
          for (final b in branches) CheckboxListTile(
            key: Key('branch-${b.id}'), contentPadding: EdgeInsets.zero, title: Text(b.name), value: _branches.contains(b.id),
            onChanged: (v) => setState(() => v! ? _branches.add(b.id) : _branches.remove(b.id)),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(l.assignServices, style: t.textTheme.titleMedium),
          for (final s in services) CheckboxListTile(
            key: Key('service-${s.id}'), contentPadding: EdgeInsets.zero, title: Text(s.name), value: _services.contains(s.id),
            onChanged: (v) => setState(() => v! ? _services.add(s.id) : _services.remove(s.id)),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const Key('saveAssignments'),
            onPressed: _busy ? null : () async {
              setState(() => _busy = true);
              final ok = await guarded(context, () => ref.read(bookingActionsProvider).setAssignments(widget.employee.id, _branches.toList(), _services.toList()));
              if (!context.mounted) return;
              if (ok) { Navigator.pop(context); } else { setState(() => _busy = false); }
            },
            child: Text(l.save),
          ),
        ]),
      ),
    );
  }
}
