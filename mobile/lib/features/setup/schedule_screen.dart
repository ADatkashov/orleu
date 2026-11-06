import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/models.dart';
import '../../core/data/repository.dart';
import '../../core/design/tokens.dart';
import '../../core/tz.dart';
import '../../core/widgets/common.dart';
import '../../l10n/gen/app_localizations.dart';
import 'setup_common.dart';

/// Opens the platform date-range picker. Replaced in tests.
final dateRangePickerProvider = Provider<Future<DateTimeRange?> Function(BuildContext)>((ref) => (context) => showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    ));

List<String> _times() => [for (var m = 0; m < 24 * 60; m += 30) '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}'];

/// Weekly working hours of one specialist (several ranges per day = breaks) and their time off.
class ScheduleScreen extends ConsumerStatefulWidget {
  final String employeeId;
  const ScheduleScreen({super.key, required this.employeeId});
  @override
  ConsumerState<ScheduleScreen> createState() => _State();
}

class _State extends ConsumerState<ScheduleScreen> {
  List<ScheduleRange>? _ranges; // null until loaded from the server; [] = follow the location
  String? _error;
  int? _affected;
  bool _busy = false;

  void _loadOnce(EmployeeSchedule s) => _ranges ??= List.of(s.hours);

  String _dayName(BuildContext context, int day) =>
      DateFormat.EEEE(Localizations.localeOf(context).toLanguageTag()).format(DateTime(2024, 1, day)); // 2024-01-01 is a Monday

  Future<void> _save() async {
    setState(() { _busy = true; _error = null; _affected = null; });
    int? affected;
    final err = await attempt(context, () async { affected = await ref.read(bookingActionsProvider).setEmployeeHours(widget.employeeId, _ranges!); });
    if (!mounted) return;
    setState(() { _busy = false; _error = err; _affected = affected; });
    if (err == null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).scheduleSaved)));
  }

  Future<void> _addRange(int day) async {
    final r = await showDialog<ScheduleRange>(context: context, builder: (_) => _RangeDialog(day: day));
    if (r != null) setState(() => _ranges = [..._ranges!, r]);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final zone = ref.watch(businessZoneProvider);
    final name = ref.watch(employeesProvider).value?.where((e) => e.id == widget.employeeId).firstOrNull?.displayName ?? '';
    final data = ref.watch(employeeScheduleProvider(widget.employeeId));
    return Scaffold(
      appBar: AppBar(title: Text(name.isEmpty ? l.scheduleTitle : '$name · ${l.scheduleTitle}')),
      body: data.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(employeeScheduleProvider)),
        data: (s) {
          _loadOnce(s);
          final follow = _ranges!.isEmpty;
          return ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
            SwitchListTile(
              key: const Key('followBranch'), contentPadding: EdgeInsets.zero, title: Text(l.scheduleFollow), subtitle: Text(l.scheduleFollowNote), value: follow,
              onChanged: (v) => setState(() => _ranges = v ? [] : [for (var d = 1; d <= 5; d++) ScheduleRange(d, '09:00', '18:00')]),
            ),
            if (!follow) ...[
              Text(l.scheduleBreakHint, style: t.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              for (var day = 1; day <= 7; day++) Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 110, child: Text(_dayName(context, day), style: t.textTheme.titleSmall)),
                  Expanded(
                    child: Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      for (final r in _ranges!.where((r) => r.day == day).toList()..sort((a, b) => a.start.compareTo(b.start)))
                        InputChip(key: Key('range-$day-${r.start}'), label: Text('${r.start}–${r.end}'), onDeleted: () => setState(() => _ranges = _ranges!.where((x) => x != r).toList())),
                      if (!_ranges!.any((r) => r.day == day)) Text(l.scheduleDayOff, key: Key('off-$day'), style: t.textTheme.bodySmall),
                      IconButton(key: Key('addRange-$day'), tooltip: l.scheduleAddRange, icon: const Icon(Icons.add_circle_outline), onPressed: () => _addRange(day)),
                    ]),
                  ),
                ]),
              ),
            ],
            FormError(_error),
            if (_affected != null && _affected! > 0) Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(l.scheduleAffected(_affected!), key: const Key('affected'), style: TextStyle(color: AppColors.warning)),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(key: const Key('saveHours'), style: FilledButton.styleFrom(minimumSize: const Size(96, 44)), onPressed: _busy ? null : _save, child: Text(l.scheduleSave)),
            const SizedBox(height: AppSpacing.lg),
            Row(children: [
              Expanded(child: Text(l.timeOffTitle, style: t.textTheme.titleMedium)),
              TextButton.icon(key: const Key('addTimeOff'), icon: const Icon(Icons.add), label: Text(l.timeOffAdd), onPressed: () => showDialog<void>(context: context, builder: (_) => _TimeOffDialog(employeeId: widget.employeeId))),
            ]),
            if (s.timeOff.isEmpty) Text(l.timeOffNone, key: const Key('noTimeOff'), style: t.textTheme.bodySmall),
            for (final o in s.timeOff) Card(
              child: ListTile(
                key: Key('timeOff-${o.id}'),
                title: Text('${DateFormat('dd.MM.yyyy').format(wallFromInstant(o.startsAt, zone))} – ${DateFormat('dd.MM.yyyy').format(wallFromInstant(o.endsAt.subtract(const Duration(minutes: 1)), zone))}'),
                subtitle: Text([if (o.reason != null) o.reason!, if (o.affectedBookings > 0) l.timeOffAffected(o.affectedBookings)].join(' · ')),
                trailing: IconButton(key: Key('removeTimeOff-${o.id}'), tooltip: l.timeOffRemove, icon: const Icon(Icons.delete_outline), onPressed: () => guarded(context, () => ref.read(bookingActionsProvider).removeTimeOff(widget.employeeId, o.id))),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _RangeDialog extends StatefulWidget {
  final int day;
  const _RangeDialog({required this.day});
  @override
  State<_RangeDialog> createState() => _RangeState();
}

class _RangeState extends State<_RangeDialog> {
  String _start = '09:00', _end = '18:00';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final times = _times();
    final ends = [...times.skip(1), '23:59'];
    return AlertDialog(
      title: Text(l.scheduleAddRange),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(key: const Key('rangeStart'), initialValue: _start, decoration: InputDecoration(labelText: l.scheduleFrom), items: [for (final x in times) DropdownMenuItem(value: x, child: Text(x))], onChanged: (v) => setState(() => _start = v!)),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(key: const Key('rangeEnd'), initialValue: _end, decoration: InputDecoration(labelText: l.scheduleTo), items: [for (final x in ends) DropdownMenuItem(value: x, child: Text(x))], onChanged: (v) => setState(() => _end = v!)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(key: const Key('confirmRange'), style: FilledButton.styleFrom(minimumSize: const Size(96, 44)), onPressed: () => Navigator.pop(context, ScheduleRange(widget.day, _start, _end)), child: Text(l.save)),
      ],
    );
  }
}

class _TimeOffDialog extends ConsumerStatefulWidget {
  final String employeeId;
  const _TimeOffDialog({required this.employeeId});
  @override
  ConsumerState<_TimeOffDialog> createState() => _TimeOffState();
}

class _TimeOffState extends ConsumerState<_TimeOffDialog> {
  DateTimeRange? _range;
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final fmt = DateFormat('dd.MM.yyyy');
    return AlertDialog(
      title: Text(l.timeOffAdd),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        OutlinedButton.icon(
          key: const Key('pickDates'), icon: const Icon(Icons.date_range),
          label: Text(_range == null ? l.timeOffAdd : '${fmt.format(_range!.start)} – ${fmt.format(_range!.end)}'),
          onPressed: () async {
            final r = await ref.read(dateRangePickerProvider)(context);
            if (r != null && mounted) setState(() => _range = r);
          },
        ),
        TextField(key: const Key('timeOffReason'), controller: _reason, maxLength: 200, decoration: InputDecoration(labelText: l.timeOffReason)),
        FormError(_error),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          key: const Key('confirmTimeOff'),
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: _busy || _range == null ? null : () async {
            setState(() { _busy = true; _error = null; });
            final err = await attempt(context, () => ref.read(bookingActionsProvider).addTimeOff(widget.employeeId, _range!.start, _range!.end, _reason.text));
            if (!context.mounted) return;
            if (err == null) { Navigator.pop(context); } else { setState(() { _busy = false; _error = err; }); }
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}
