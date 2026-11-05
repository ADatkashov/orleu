import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/models.dart';
import '../../core/data/repository.dart';
import '../../core/tz.dart';
import '../../core/design/tokens.dart';
import '../../core/widgets/common.dart';
import '../../l10n/gen/app_localizations.dart';

/// Date button + grid of free times from the backend. The backend decides what is free; the UI only displays it.
/// Times are shown in the device's timezone (the business timezone is not applied yet - see docs).
class SlotPicker extends ConsumerStatefulWidget {
  final String branchId, serviceId;
  final String? employeeId, excludeBookingId;
  final ValueChanged<Slot?> onSelected;
  final DateTime? initialDate;
  const SlotPicker({super.key, required this.branchId, required this.serviceId, this.employeeId, this.excludeBookingId, required this.onSelected, this.initialDate});

  @override
  ConsumerState<SlotPicker> createState() => _SlotPickerState();
}

class _SlotPickerState extends ConsumerState<SlotPicker> {
  DateTime? _dateOverride;
  Slot? _selected;

  /// Selected calendar date in the BUSINESS timezone (defaults to today there, or to the booking being moved).
  DateTime get _date => _dateOverride ?? dayStart(widget.initialDate ?? nowWall(ref.read(businessZoneProvider)));

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_date);

  @override
  void didUpdateWidget(covariant SlotPicker old) {
    super.didUpdateWidget(old);
    if (old.branchId != widget.branchId || old.serviceId != widget.serviceId || old.employeeId != widget.employeeId) _select(null);
  }

  void _select(Slot? s) {
    setState(() => _selected = s);
    widget.onSelected(s);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final slots = ref.watch(availabilityProvider((
      branchId: widget.branchId, serviceId: widget.serviceId, employeeId: widget.employeeId, date: _dateStr, excludeBookingId: widget.excludeBookingId)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l.pickDate, style: t.textTheme.bodySmall),
      const SizedBox(height: AppSpacing.xs),
      OutlinedButton.icon(
        key: const Key('pickDate'),
        icon: const Icon(Icons.calendar_today, size: 18),
        label: Text(DateFormat.yMMMEd(locale).format(_date)),
        onPressed: () async {
          final today = dayStart(nowWall(ref.read(businessZoneProvider)));
          final cur = _date;
          final d = await showDatePicker(context: context, initialDate: cur.isBefore(today) ? today : cur, firstDate: today, lastDate: today.add(const Duration(days: 365)));
          if (d != null) { setState(() => _dateOverride = d); _select(null); }
        },
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), alignment: Alignment.centerLeft),
      ),
      const SizedBox(height: AppSpacing.md),
      Text(l.pickTime, style: t.textTheme.bodySmall),
      const SizedBox(height: AppSpacing.xs),
      slots.when(
        loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.md), child: Center(child: CircularProgressIndicator())),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(availabilityProvider)),
        data: (list) => list.isEmpty
            ? Padding(padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm), child: Text(l.noSlots, key: const Key('noSlots'), style: t.textTheme.bodySmall))
            : Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
                for (final s in list) ChoiceChip(
                  key: Key('slot-${s.instant.toIso8601String()}'),
                  label: Text(DateFormat.Hm().format(s.start)),
                  selected: _selected?.instant == s.instant,
                  onSelected: (_) => _select(s),
                ),
              ]),
      ),
    ]);
  }
}
