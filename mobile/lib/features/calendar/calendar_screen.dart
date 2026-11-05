import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/models.dart';
import '../../core/data/repository.dart';
import '../../core/design/tokens.dart';
import '../../core/errors.dart';
import '../../core/widgets/common.dart';
import '../../l10n/gen/app_localizations.dart';
import 'booking_forms.dart';

/// Day view: navigate days, open a booking for details and status actions (validated by the backend).
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});
  @override
  ConsumerState<CalendarScreen> createState() => _State();
}

class _State extends ConsumerState<CalendarScreen> {
  DateTime _day = dayStart(DateTime.now());

  void _shift(int days) => setState(() => _day = _day.add(Duration(days: days)));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final bookings = ref.watch(bookingsProvider(_day));
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('newBooking'), icon: const Icon(Icons.add), label: Text(l.newBooking),
        onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => const NewBookingSheet()),
      ),
      appBar: AppBar(
        title: Text(DateFormat.MMMEd(locale).format(_day)),
        actions: [
          IconButton(icon: const Icon(Icons.chevron_left), tooltip: '−1', onPressed: () => _shift(-1)),
          IconButton(icon: const Icon(Icons.today), tooltip: DateFormat.MMMd(locale).format(DateTime.now()), onPressed: () => setState(() => _day = dayStart(DateTime.now()))),
          IconButton(icon: const Icon(Icons.chevron_right), tooltip: '+1', onPressed: () => _shift(1)),
        ],
      ),
      body: bookings.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(bookingsProvider)),
        data: (list) => list.isEmpty
            ? EmptyState(icon: Icons.event_available_outlined, text: l.noBookings)
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(bookingsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) {
                    final b = list[i];
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
                  },
                ),
              ),
      ),
    );
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
