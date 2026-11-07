import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/models.dart';
import '../../core/data/repository.dart';
import '../../core/tz.dart';
import '../../core/design/tokens.dart';
import '../../core/errors.dart';
import '../../core/widgets/common.dart';
import '../../l10n/gen/app_localizations.dart';
import 'booking_forms.dart';

enum CalendarMode { day, week, month }

/// Bookings that occupy a specialist's time; cancelled, expired and no-show ones do not count as load.
bool occupiesTime(Booking b) => !const {'CANCELLED', 'EXPIRED', 'NO_SHOW'}.contains(b.status);

/// Monday of the week containing [d] (ISO weeks, as used by the working-hours settings).
DateTime weekStart(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// Day / week / month views over the same backend list endpoint, filterable by specialist (server side) and location (client side).
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});
  @override
  ConsumerState<CalendarScreen> createState() => _State();
}

class _State extends ConsumerState<CalendarScreen> {
  DateTime? _anchor; // null = today in the business timezone
  CalendarMode _mode = CalendarMode.day;
  String? _employeeId, _branchId;

  DateTime _shift(DateTime current, int dir) => switch (_mode) {
        CalendarMode.day => DateTime(current.year, current.month, current.day + dir),
        CalendarMode.week => DateTime(current.year, current.month, current.day + 7 * dir),
        CalendarMode.month => DateTime(current.year, current.month + dir, 1),
      };

  /// First day (inclusive) and end (exclusive) of what is shown.
  (DateTime, DateTime) _range(DateTime anchor) => switch (_mode) {
        CalendarMode.day => (dayStart(anchor), nextDay(anchor)),
        CalendarMode.week => (weekStart(anchor), DateTime(weekStart(anchor).year, weekStart(anchor).month, weekStart(anchor).day + 7)),
        CalendarMode.month => (DateTime(anchor.year, anchor.month, 1), DateTime(anchor.year, anchor.month + 1, 1)),
      };

  void _openDay(DateTime d) => setState(() { _anchor = d; _mode = CalendarMode.day; });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final zone = ref.watch(businessZoneProvider);
    final today = dayStart(nowWall(zone));
    final anchor = _anchor ?? today;
    final (from, to) = _range(anchor);
    final query = (from, to, _employeeId);
    final bookings = ref.watch(bookingsRangeProvider(query));
    final employees = ref.watch(employeesProvider).value?.where((e) => e.active).toList() ?? const <Employee>[];
    final branches = ref.watch(branchesProvider).value?.where((b) => b.active).toList() ?? const <Branch>[];
    final title = switch (_mode) {
      CalendarMode.day => DateFormat.MMMEd(locale).format(anchor),
      CalendarMode.week => '${DateFormat.MMMd(locale).format(from)} – ${DateFormat.MMMd(locale).format(DateTime(to.year, to.month, to.day - 1))}',
      CalendarMode.month => DateFormat.yMMMM(locale).format(anchor),
    };
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('newBooking'), icon: const Icon(Icons.add), label: Text(l.newBooking),
        onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => const NewBookingSheet()),
      ),
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(key: const Key('prev'), icon: const Icon(Icons.chevron_left), tooltip: '−1', onPressed: () => setState(() => _anchor = _shift(anchor, -1))),
          IconButton(key: const Key('today'), icon: const Icon(Icons.today), tooltip: DateFormat.MMMd(locale).format(today), onPressed: () => setState(() => _anchor = null)),
          IconButton(key: const Key('next'), icon: const Icon(Icons.chevron_right), tooltip: '+1', onPressed: () => setState(() => _anchor = _shift(anchor, 1))),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
          child: SegmentedButton<CalendarMode>(
            key: const Key('calMode'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: CalendarMode.day, label: Text(l.calDay)),
              ButtonSegment(value: CalendarMode.week, label: Text(l.calWeek)),
              ButtonSegment(value: CalendarMode.month, label: Text(l.calMonth)),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
        ),
        if (employees.length > 1 || branches.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
              if (employees.length > 1)
                _Filter(
                  key: const Key('filterEmployee'), icon: Icons.badge_outlined, allLabel: l.filterAllSpecialists, value: _employeeId,
                  items: {for (final e in employees) e.id: e.displayName},
                  onChanged: (v) => setState(() => _employeeId = v),
                ),
              if (branches.length > 1)
                _Filter(
                  key: const Key('filterBranch'), icon: Icons.storefront_outlined, allLabel: l.filterAllLocations, value: _branchId,
                  items: {for (final b in branches) b.id: b.name},
                  onChanged: (v) => setState(() => _branchId = v),
                ),
            ]),
          ),
        Expanded(
          child: bookings.when(
            loading: () => const SkeletonList(),
            error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(bookingsRangeProvider)),
            data: (all) {
              final list = _branchId == null ? all : all.where((b) => b.branchId == _branchId).toList();
              Future<void> refresh() async => ref.invalidate(bookingsRangeProvider);
              return switch (_mode) {
                CalendarMode.day => list.isEmpty
                    ? EmptyState(icon: Icons.event_available_outlined, text: l.noBookings)
                    : RefreshIndicator(onRefresh: refresh, child: _BookingList(list)),
                CalendarMode.week => RefreshIndicator(onRefresh: refresh, child: _WeekView(start: from, bookings: list, today: today, onOpenDay: _openDay)),
                CalendarMode.month => RefreshIndicator(onRefresh: refresh, child: _MonthView(month: from, bookings: list, today: today, onOpenDay: _openDay)),
              };
            },
          ),
        ),
      ]),
    );
  }
}

class _Filter extends StatelessWidget {
  final IconData icon;
  final String allLabel;
  final String? value;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;
  const _Filter({super.key, required this.icon, required this.allLabel, required this.value, required this.items, required this.onChanged});
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        initialValue: value ?? '',
        // A PopupMenuItem whose value is null is treated as "dismissed" and never reaches onSelected, so "all" is the empty string.
        onSelected: (v) => onChanged(v.isEmpty ? null : v),
        itemBuilder: (_) => [PopupMenuItem<String>(value: '', child: Text(allLabel)), for (final e in items.entries) PopupMenuItem<String>(value: e.key, child: Text(e.value))],
        child: Chip(avatar: Icon(icon, size: 18), label: Text(value == null ? allLabel : (items[value] ?? allLabel))),
      );
}

class _BookingCard extends StatelessWidget {
  final Booking b;
  const _BookingCard(this.b);
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => BookingSheet(b)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(children: [
            SizedBox(width: 56, child: Text(DateFormat.Hm().format(b.startsAt), style: t.textTheme.titleMedium)),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.serviceName, style: t.textTheme.titleMedium),
              Text('${b.customerName} · ${b.employeeName}', style: t.textTheme.bodySmall),
            ])),
            StatusChip(b.status),
          ]),
        ),
      ),
    );
  }
}

class _BookingList extends StatelessWidget {
  final List<Booking> list;
  const _BookingList(this.list);
  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, i) => _BookingCard(list[i]),
      );
}

/// Seven day sections (Mon–Sun); a day header opens the day view.
class _WeekView extends StatelessWidget {
  final DateTime start, today;
  final List<Booking> bookings;
  final ValueChanged<DateTime> onOpenDay;
  const _WeekView({required this.start, required this.bookings, required this.today, required this.onOpenDay});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 96), children: [
      for (var i = 0; i < 7; i++) ...[
        Builder(builder: (_) {
          final d = DateTime(start.year, start.month, start.day + i);
          final dayBookings = bookings.where((b) => dayStart(b.startsAt) == d).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));
          final active = dayBookings.where(occupiesTime).length;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(
              key: Key('weekDay-$i'),
              onTap: () => onOpenDay(d),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(children: [
                  Expanded(child: Text(DateFormat.MMMEd(locale).format(d),
                      style: t.textTheme.titleSmall?.copyWith(color: d == today ? t.colorScheme.primary : null, fontWeight: d == today ? FontWeight.w700 : null))),
                  Text(l.calBookingsCount(active), style: t.textTheme.bodySmall),
                ]),
              ),
            ),
            if (dayBookings.isEmpty) Text('—', style: t.textTheme.bodySmall)
            else for (final b in dayBookings) Padding(padding: const EdgeInsets.only(bottom: AppSpacing.xs), child: _BookingCard(b)),
          ]);
        }),
      ],
    ]);
  }
}

/// Month grid (Mon–Sun columns) with the number of time-occupying bookings per day; a day opens the day view.
class _MonthView extends StatelessWidget {
  final DateTime month, today;
  final List<Booking> bookings;
  final ValueChanged<DateTime> onOpenDay;
  const _MonthView({required this.month, required this.bookings, required this.today, required this.onOpenDay});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday - 1;
    final counts = <DateTime, int>{};
    for (final b in bookings.where(occupiesTime)) {
      counts.update(dayStart(b.startsAt), (v) => v + 1, ifAbsent: () => 1);
    }
    final cells = lead + daysInMonth;
    final rows = (cells / 7).ceil();
    final monday = DateTime(2024, 1, 1); // a Monday: only used to get localized weekday names
    return ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96), children: [
      Row(children: [
        for (var i = 0; i < 7; i++) Expanded(child: Center(child: Text(DateFormat.E(locale).format(DateTime(monday.year, monday.month, monday.day + i)), style: t.textTheme.labelSmall))),
      ]),
      const SizedBox(height: AppSpacing.xs),
      for (var r = 0; r < rows; r++) Row(children: [
        for (var c = 0; c < 7; c++) Expanded(child: Builder(builder: (_) {
          final n = r * 7 + c - lead + 1;
          if (n < 1 || n > daysInMonth) return const SizedBox(height: 56);
          final d = DateTime(month.year, month.month, n);
          final count = counts[d] ?? 0;
          final isToday = d == today;
          return InkWell(
            key: Key('monthDay-$n'),
            onTap: () => onOpenDay(d),
            child: Container(
              height: 56,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isToday ? t.colorScheme.primary : t.dividerColor),
                color: count > 0 ? t.colorScheme.primary.withValues(alpha: (0.08 + 0.06 * count).clamp(0.08, 0.4)) : null,
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('$n', style: t.textTheme.bodyMedium?.copyWith(fontWeight: isToday ? FontWeight.w700 : null)),
                if (count > 0) Text('$count', key: Key('monthCount-$n'), style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.primary, fontWeight: FontWeight.w700)),
              ]),
            ),
          );
        })),
      ]),
    ]);
  }
}

class BookingSheet extends ConsumerStatefulWidget {
  final Booking booking;
  const BookingSheet(this.booking, {super.key});
  @override
  ConsumerState<BookingSheet> createState() => _SheetState();
}

class _SheetState extends ConsumerState<BookingSheet> {
  bool _busy = false;
  String? _error;

  String _action(AppLocalizations l, String s) => switch (s) {
        'CONFIRMED' => l.actionConfirm,
        'CHECKED_IN' => l.actionCheckIn,
        'IN_PROGRESS' => l.actionStart,
        'COMPLETED' => l.actionComplete,
        'NO_SHOW' => l.actionNoShow,
        _ => l.actionCancel,
      };

  String _pay(AppLocalizations l, String s) => switch (s) {
        'UNPAID' => l.payUnpaid,
        'PARTIALLY_PAID' => l.payPartial,
        'DEPOSIT_PAID' => l.payDepositPaid,
        'PAID' => l.payPaid,
        _ => l.payRefunded,
      };

  Future<void> _do(String status) async {
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(bookingActionsProvider).transition(widget.booking.id, status);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() { _error = errorText(context, e); _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final b = widget.booking, f = b.financials;
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(k, style: t.textTheme.bodySmall), Flexible(child: Text(v, textAlign: TextAlign.end))]),
        );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [Expanded(child: Text(b.serviceName, style: t.textTheme.titleLarge)), StatusChip(b.status)]),
          Text(DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).add_Hm().format(b.startsAt), style: t.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          row(l.customer, '${b.customerName}\n${b.customerPhone}'),
          row(l.employee, b.employeeName),
          const Divider(),
          row(l.price, money(context, f.price, b.currency)),
          row(l.deposit, money(context, f.deposit, b.currency)),
          row(l.paid, money(context, f.paid, b.currency)),
          row(l.remaining, money(context, f.remaining, b.currency)),
          row(l.paymentStatus, _pay(l, f.paymentStatus)),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: AppSpacing.sm), child: Text(_error!, style: TextStyle(color: t.colorScheme.error))),
          const SizedBox(height: AppSpacing.md),
          if (b.canTakePayment) Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: FilledButton.icon(
              key: const Key('recordPayment'),
              icon: const Icon(Icons.payments_outlined),
              label: Text(l.recordPayment),
              onPressed: _busy ? null : () {
                final nav = Navigator.of(context);
                nav.pop();
                showModalBottomSheet(context: nav.context, isScrollControlled: true, showDragHandle: true, builder: (_) => PaymentSheet(booking: b));
              },
            ),
          ),
          if (b.canTakePayment && canCloseCash(ref.watch(myRoleProvider).value)) Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: OutlinedButton.icon(
              key: const Key('giftPayAction'),
              icon: const Icon(Icons.card_giftcard),
              label: Text(l.giftPay),
              onPressed: _busy ? null : () {
                final nav = Navigator.of(context);
                nav.pop();
                showModalBottomSheet(context: nav.context, isScrollControlled: true, showDragHandle: true, builder: (_) => GiftPaymentSheet(booking: b));
              },
            ),
          ),
          if (f.paid > 0 && canRefund(ref.watch(myRoleProvider).value)) Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: OutlinedButton.icon(
              key: const Key('refundAction'),
              icon: const Icon(Icons.undo),
              label: Text(l.refundAction),
              onPressed: _busy ? null : () {
                final nav = Navigator.of(context);
                nav.pop();
                showModalBottomSheet(context: nav.context, isScrollControlled: true, showDragHandle: true, builder: (_) => RefundSheet(booking: b));
              },
            ),
          ),
          if (b.canReschedule) Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: OutlinedButton.icon(
              key: const Key('reschedule'),
              icon: const Icon(Icons.event_repeat),
              label: Text(l.rescheduleAction),
              onPressed: _busy ? null : () {
                final nav = Navigator.of(context);
                nav.pop();
                showModalBottomSheet(context: nav.context, isScrollControlled: true, showDragHandle: true, builder: (_) => RescheduleSheet(booking: b));
              },
            ),
          ),
          for (final s in b.nextActions) Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: s == 'CANCELLED' || s == 'NO_SHOW'
                ? OutlinedButton(onPressed: _busy ? null : () => _do(s), child: Text(_action(l, s)))
                : FilledButton(onPressed: _busy ? null : () => _do(s), child: Text(_action(l, s))),
          ),
        ]),
      ),
    );
  }
}
