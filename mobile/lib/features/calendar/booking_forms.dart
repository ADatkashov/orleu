import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/models.dart';
import '../../core/data/repository.dart';
import '../../core/design/tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../setup/setup_common.dart';
import 'slot_picker.dart';

/// Create a booking on behalf of a client (phone call / walk-in).
class NewBookingSheet extends ConsumerStatefulWidget {
  const NewBookingSheet({super.key});
  @override
  ConsumerState<NewBookingSheet> createState() => _NewBookingState();
}

class _NewBookingState extends ConsumerState<NewBookingSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _phone = TextEditingController(), _notes = TextEditingController();
  String? _serviceId, _branchId, _employeeId; // _employeeId null = any
  Slot? _slot;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final services = ref.watch(servicesProvider).value ?? const <ServiceItem>[];
    final branches = ref.watch(branchesProvider).value ?? const <Branch>[];
    final employees = ref.watch(employeesProvider).value ?? const <Employee>[];

    List<Employee> eligible(String? svc, String? br) => [
          for (final e in employees) if (svc != null && e.serviceIds.contains(svc) && (br == null || e.branchIds.contains(br))) e
        ];
    final bookableServices = [for (final s in services) if (eligible(s.id, null).isNotEmpty) s];
    final eligibleBranches = _serviceId == null ? const <Branch>[] : [
      for (final b in branches) if (eligible(_serviceId, b.id).isNotEmpty && b.hours.isNotEmpty) b
    ];
    final eligibleEmps = eligible(_serviceId, _branchId);

    InputDecoration deco(String label) => InputDecoration(labelText: label);

    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text(l.newBooking, style: t.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            if (bookableServices.isEmpty) Text(l.setupFirst, key: const Key('setupFirst')) else ...[
              DropdownButtonFormField<String>(
                key: const Key('selService'), initialValue: _serviceId, decoration: deco(l.selectService), isExpanded: true,
                items: [for (final s in bookableServices) DropdownMenuItem(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis))],
                validator: (v) => v == null ? l.validationRequired : null,
                onChanged: (v) => setState(() {
                  _serviceId = v; _employeeId = null; _slot = null;
                  final bs = [for (final b in branches) if (eligible(v, b.id).isNotEmpty && b.hours.isNotEmpty) b];
                  _branchId = bs.length == 1 ? bs.first.id : null;
                }),
              ),
              const SizedBox(height: AppSpacing.md),
              if (eligibleBranches.length > 1) ...[
                DropdownButtonFormField<String>(
                  key: ValueKey('selBranch-$_serviceId'), initialValue: _branchId, decoration: deco(l.selectLocation), isExpanded: true,
                  items: [for (final b in eligibleBranches) DropdownMenuItem(value: b.id, child: Text(b.name, overflow: TextOverflow.ellipsis))],
                  validator: (v) => v == null ? l.validationRequired : null,
                  onChanged: (v) => setState(() { _branchId = v; _employeeId = null; _slot = null; }),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (_branchId != null) ...[
                DropdownButtonFormField<String?>(
                  key: ValueKey('selEmp-$_serviceId-$_branchId'), initialValue: _employeeId, decoration: deco(l.selectSpecialist), isExpanded: true,
                  items: [
                    DropdownMenuItem<String?>(value: null, child: Text(l.anySpecialist)),
                    for (final e in eligibleEmps) DropdownMenuItem<String?>(value: e.id, child: Text(e.displayName, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() { _employeeId = v; _slot = null; }),
                ),
                const SizedBox(height: AppSpacing.md),
                SlotPicker(
                  key: ValueKey('slots-$_serviceId-$_branchId-$_employeeId'),
                  branchId: _branchId!, serviceId: _serviceId!, employeeId: _employeeId,
                  onSelected: (s) => setState(() => _slot = s),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              TextFormField(key: const Key('clientName'), controller: _name, decoration: deco(l.clientName), textCapitalization: TextCapitalization.words,
                  validator: (v) => v == null || v.trim().isEmpty ? l.validationRequired : null),
              const SizedBox(height: AppSpacing.md),
              TextFormField(key: const Key('clientPhone'), controller: _phone, keyboardType: TextInputType.phone, decoration: deco(l.clientPhone),
                  validator: (v) => v == null || !phoneE164.hasMatch(normalizePhone(v)) ? l.validationPhone : null),
              const SizedBox(height: AppSpacing.md),
              TextFormField(controller: _notes, decoration: deco(l.notesOptional), maxLines: 2),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                key: const Key('createBooking'),
                onPressed: _busy || _slot == null ? null : () async {
                  if (!_form.currentState!.validate()) return;
                  setState(() => _busy = true);
                  final ok = await guarded(context, () => ref.read(bookingActionsProvider).createBooking(
                        branchId: _branchId!, serviceId: _serviceId!, employeeId: _employeeId, startsAt: _slot!.start,
                        name: _name.text.trim(), phone: normalizePhone(_phone.text), notes: _notes.text.trim()));
                  if (!context.mounted) return;
                  if (ok) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.bookingCreated), behavior: SnackBarBehavior.floating));
                  } else {
                    ref.invalidate(availabilityProvider); // the slot may have been taken: show fresh availability
                    setState(() { _busy = false; _slot = null; });
                  }
                },
                child: Text(l.bookAction),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Move an existing booking to another free time (same specialist). The booking's own time counts as free.
class RescheduleSheet extends ConsumerStatefulWidget {
  final Booking booking;
  const RescheduleSheet({super.key, required this.booking});
  @override
  ConsumerState<RescheduleSheet> createState() => _RescheduleState();
}

class _RescheduleState extends ConsumerState<RescheduleSheet> {
  Slot? _slot;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final b = widget.booking;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(l.rescheduleTitle, style: Theme.of(context).textTheme.titleLarge),
          Text('${b.serviceName} · ${b.customerName}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          SlotPicker(branchId: b.branchId, serviceId: b.serviceId, employeeId: b.employeeId, excludeBookingId: b.id, initialDate: b.startsAt, onSelected: (s) => setState(() => _slot = s)),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            key: const Key('moveBooking'),
            onPressed: _busy || _slot == null ? null : () async {
              setState(() => _busy = true);
              final ok = await guarded(context, () => ref.read(bookingActionsProvider).reschedule(b.id, _slot!.start));
              if (!context.mounted) return;
              if (ok) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.bookingMoved), behavior: SnackBarBehavior.floating));
              } else {
                ref.invalidate(availabilityProvider);
                setState(() { _busy = false; _slot = null; });
              }
            },
            child: Text(l.moveHere),
          ),
        ]),
      ),
    );
  }
}
