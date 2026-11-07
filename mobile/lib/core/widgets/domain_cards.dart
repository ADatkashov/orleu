import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/gen/app_localizations.dart';
import '../data/models.dart';
import '../design/tokens.dart';
import 'app_card.dart';
import 'avatar.dart';
import 'common.dart' show money;
import 'status_badge.dart';

/// A booking in a list: avatar, service, client · specialist, time range and status.
class BookingCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback? onTap;
  final bool showPayment;
  /// Calendar layout: start/end times in a leading column instead of a trailing start time.
  final bool timeline;
  const BookingCard({super.key, required this.booking, this.onTap, this.showPayment = false, this.timeline = false});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final b = booking;
    final time = DateFormat.Hm().format(b.startsAt);
    final f = b.financials;
    final payment = !showPayment ? null : f.remaining > 0 ? '${l.remaining}: ${money(context, f.remaining, b.currency)}' : l.paid;
    if (timeline) {
      return AppCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 12, AppSpacing.md, 12),
        semanticLabel: '${b.serviceName}, ${b.customerName}, $time–${DateFormat.Hm().format(b.endsAt)}',
        child: ExcludeSemantics(
          child: Row(children: [
            SizedBox(
              width: 48,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(time, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                Text(DateFormat.Hm().format(b.endsAt), style: t.textTheme.bodySmall),
              ]),
            ),
            Container(width: 4, height: 44, margin: const EdgeInsets.only(right: AppSpacing.sm + 4), decoration: BoxDecoration(color: statusAccent(context, b.status), borderRadius: BorderRadius.circular(2))),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b.serviceName, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.titleSmall?.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text('${b.customerName} · ${b.employeeName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall),
                if (payment != null) Text(payment, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall),
              ]),
            ),
            const SizedBox(width: AppSpacing.sm),
            BookingStatusBadge(b.status),
          ]),
        ),
      );
    }
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 12, AppSpacing.md, 12),
      child: Row(children: [
        Container(width: 4, height: 48, decoration: BoxDecoration(color: statusAccent(context, b.status), borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: AppSpacing.sm + 4),
        AppAvatar(b.customerName),
        const SizedBox(width: AppSpacing.sm + 4),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(b.serviceName, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.titleSmall?.copyWith(fontSize: 15)),
            const SizedBox(height: 2),
            Text('${b.customerName} · ${b.employeeName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall),
            if (payment != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(payment, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall)),
          ]),
        ),
        const SizedBox(width: AppSpacing.sm),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(time, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          BookingStatusBadge(b.status),
        ]),
      ]),
    );
  }
}

class CustomerCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback? onTap;
  const CustomerCard({super.key, required this.customer, this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = customer;
    return AppCard(
      onTap: onTap, padding: const EdgeInsets.all(12),
      child: Row(children: [
        AppAvatar(c.fullName),
        const SizedBox(width: AppSpacing.sm + 4),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.titleSmall?.copyWith(fontSize: 15)),
            const SizedBox(height: 2),
            Text(c.phone, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall),
            if (c.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(spacing: 6, runSpacing: 4, children: [for (final tag in c.tags.take(4)) StatusBadge('#$tag', dot: false)]),
              ),
          ]),
        ),
        if (c.blocked) Icon(Icons.block_rounded, color: context.palette.danger, semanticLabel: AppLocalizations.of(context).blocked)
        else Icon(Icons.chevron_right_rounded, color: t.colorScheme.onSurfaceVariant),
      ]),
    );
  }
}

class ServiceCard extends StatelessWidget {
  final ServiceItem service;
  final String currency;
  final VoidCallback? onTap;
  final Widget? trailing;
  const ServiceCard({super.key, required this.service, required this.currency, this.onTap, this.trailing});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final s = service;
    return Opacity(
      opacity: s.active ? 1 : 0.6,
      child: AppCard(
        onTap: onTap, padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: t.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(AppRadius.control)),
            child: Icon(Icons.content_cut_rounded, size: AppIconSize.md, color: t.colorScheme.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.titleSmall?.copyWith(fontSize: 15)),
              const SizedBox(height: 2),
              Text('${s.durationMinutes} ${l.minutesShort}', style: t.textTheme.bodySmall),
            ]),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(money(context, s.price, currency), style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          if (trailing != null) ...[const SizedBox(width: AppSpacing.xs), trailing!],
        ]),
      ),
    );
  }
}

class EmployeeCard extends StatelessWidget {
  final Employee employee;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  const EmployeeCard({super.key, required this.employee, this.subtitle, this.onTap, this.trailing});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Opacity(
      opacity: employee.active ? 1 : 0.6,
      child: AppCard(
        onTap: onTap, padding: const EdgeInsets.all(12),
        child: Row(children: [
          AppAvatar(employee.displayName),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(employee.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.titleSmall?.copyWith(fontSize: 15)),
              if (subtitle != null) Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall),
            ]),
          ),
          ?trailing,
        ]),
      ),
    );
  }
}
