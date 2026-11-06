import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/models.dart';
import '../../core/data/repository.dart';
import '../../core/design/tokens.dart';
import '../../core/widgets/common.dart';
import '../../l10n/gen/app_localizations.dart';
import '../finance/export_section.dart';
import '../setup/setup_common.dart';

/// Customer card: measured statistics (money = cash collected, not booked value), history and editable notes.
class CustomerProfileScreen extends ConsumerWidget {
  final String customerId;
  const CustomerProfileScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final cur = ref.watch(currentBusinessProvider).value?.currency ?? 'KZT';
    final locale = Localizations.localeOf(context).toLanguageTag();
    final res = ref.watch(customerProfileProvider(customerId));
    return Scaffold(
      appBar: AppBar(title: Text(res.value?.customer.fullName ?? l.navCustomers)),
      body: res.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(customerProfileProvider)),
        data: (p) {
          final s = p.stats;
          final dash = '—';
          return ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.customer.phone, style: t.textTheme.titleMedium),
                if (p.customer.email != null && p.customer.email!.isNotEmpty) Text(p.customer.email!, style: t.textTheme.bodySmall),
              ])),
              if (p.customer.blocked) const Pill(),
            ]),
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              Expanded(child: StatTile(label: l.statVisits, value: '${s.completedVisits}')),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: StatTile(label: l.statUpcoming, value: '${s.upcoming}')),
            ]),
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              Expanded(child: StatTile(label: l.statCancelled, value: '${s.cancelled}', valueColor: s.cancelled > 0 ? AppColors.warning : null)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: StatTile(label: l.statNoShows, value: '${s.noShows}', valueColor: s.noShows > 0 ? AppColors.danger : null)),
            ]),
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              Expanded(child: StatTile(label: l.statSpent, value: money(context, s.totalSpent, cur))),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: StatTile(label: l.statAvg, value: s.averageSpendPerVisit == null ? dash : money(context, s.averageSpendPerVisit!, cur))),
            ]),
            const SizedBox(height: AppSpacing.sm),
            StatTile(label: l.statLastVisit, value: s.lastVisit == null ? l.noVisitsYet : DateFormat.yMMMd(locale).format(s.lastVisit!)),
            const SizedBox(height: AppSpacing.xs),
            Text(l.statsNote, style: t.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            Card(child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(l.notes, style: t.textTheme.titleMedium)),
                TextButton(key: const Key('editClient'), onPressed: () => showDialog(context: context, builder: (_) => _EditClientDialog(profile: p)), child: Text(l.edit)),
              ]),
              Text(p.notes == null || p.notes!.isEmpty ? dash : p.notes!, key: const Key('clientNotes')),
              const SizedBox(height: AppSpacing.sm),
              Row(children: [
                Expanded(child: Text(l.tagsTitle, style: t.textTheme.titleSmall)),
                TextButton(key: const Key('editTags'), onPressed: () => showDialog(context: context, builder: (_) => _TagsDialog(customer: p.customer)), child: Text(l.edit)),
              ]),
              p.customer.tags.isEmpty
                  ? Text(dash, key: const Key('noTags'))
                  : Wrap(spacing: AppSpacing.xs, children: [for (final tag in p.customer.tags) Chip(key: Key('tag-$tag'), label: Text(tag))]),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                key: const Key('marketingSwitch'), contentPadding: EdgeInsets.zero, title: Text(l.marketingConsent), value: p.marketingOptIn,
                onChanged: (v) => guarded(context, () => ref.read(bookingActionsProvider).updateCustomer(customerId, marketingOptIn: v)),
              ),
            ]))),
            const SizedBox(height: AppSpacing.sm),
            p.customer.blocked
                ? OutlinedButton(key: const Key('unblock'), onPressed: () => guarded(context, () => ref.read(bookingActionsProvider).setCustomerBlocked(customerId, false)), child: Text(l.unblockClient))
                : OutlinedButton(
                    key: const Key('block'), style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                    onPressed: () => showDialog(context: context, builder: (_) => _BlockDialog(customerId: customerId)), child: Text(l.blockClient)),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(key: const Key('exportClient'), icon: const Icon(Icons.download_outlined), label: Text(l.privacyExport), onPressed: () => guarded(context, () async {
              final f = await ref.read(bookingActionsProvider).exportCustomer(customerId);
              final saved = await ref.read(csvSaverProvider)(f.name, f.bytes);
              if (saved && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.privacySaved)));
            })),
            if (canErase(ref.watch(myRoleProvider).value)) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                key: const Key('eraseClient'), style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger), icon: const Icon(Icons.delete_forever_outlined),
                label: Text(l.privacyDelete), onPressed: () => showDialog(context: context, builder: (_) => _EraseDialog(customerId: customerId)),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(l.historyTitle, style: t.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            if (p.bookings.isEmpty) Text(l.noHistory, key: const Key('noHistory'), style: t.textTheme.bodySmall)
            else for (final b in p.bookings) Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Card(child: ListTile(
                key: Key('line-${b.id}'),
                title: Text(b.serviceName),
                subtitle: Text('${DateFormat.yMMMd(locale).add_Hm().format(b.startsAt)} · ${b.employeeName}'),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  StatusChip(b.status),
                  const SizedBox(height: 2),
                  Text(money(context, b.netPaid, cur), style: t.textTheme.bodySmall),
                ]),
              )),
            ),
          ]);
        },
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill({super.key});
  @override
  Widget build(BuildContext context) => Container(
        key: const Key('blockedBadge'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
        child: Text(AppLocalizations.of(context).blocked, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w600)),
      );
}

class _EditClientDialog extends ConsumerStatefulWidget {
  final CustomerProfile profile;
  const _EditClientDialog({required this.profile});
  @override
  ConsumerState<_EditClientDialog> createState() => _EditClientState();
}

class _EditClientState extends ConsumerState<_EditClientDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.customer.fullName);
  late final _email = TextEditingController(text: widget.profile.customer.email ?? '');
  late final _notes = TextEditingController(text: widget.profile.notes ?? '');
  bool _busy = false;
  String? _error;
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.editClient),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(key: const Key('editName'), controller: _name, decoration: InputDecoration(labelText: l.fullName), validator: (v) => v == null || v.trim().isEmpty ? l.validationRequired : null),
            const SizedBox(height: AppSpacing.md),
            TextFormField(key: const Key('editEmail'), controller: _email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: l.email),
                validator: (v) => v != null && v.trim().isNotEmpty && !_emailRe.hasMatch(v.trim()) ? l.validationEmail : null),
            const SizedBox(height: AppSpacing.md),
            TextFormField(key: const Key('editNotes'), controller: _notes, decoration: InputDecoration(labelText: l.notes), maxLines: 3),
            FormError(_error),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          key: const Key('saveClient'), style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: _busy ? null : () async {
            if (!_form.currentState!.validate()) return;
            setState(() { _busy = true; _error = null; });
            final err = await attempt(context, () => ref.read(bookingActionsProvider).updateCustomer(widget.profile.customer.id,
                fullName: _name.text.trim(), email: _email.text.trim(), notes: _notes.text));
            if (!context.mounted) return;
            if (err == null) { Navigator.pop(context); } else { setState(() { _busy = false; _error = err; }); }
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}

class _BlockDialog extends ConsumerStatefulWidget {
  final String customerId;
  const _BlockDialog({required this.customerId});
  @override
  ConsumerState<_BlockDialog> createState() => _BlockState();
}

class _BlockState extends ConsumerState<_BlockDialog> {
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.blockClient),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l.blockConfirm), FormError(_error)]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          key: const Key('confirmBlock'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white, minimumSize: const Size(96, 44)),
          onPressed: _busy ? null : () async {
            setState(() { _busy = true; _error = null; });
            final err = await attempt(context, () => ref.read(bookingActionsProvider).setCustomerBlocked(widget.customerId, true));
            if (!context.mounted) return;
            if (err == null) { Navigator.pop(context); } else { setState(() { _busy = false; _error = err; }); }
          },
          child: Text(l.blockClient),
        ),
      ],
    );
  }
}

/// Owner/admin only on the server; this just hides the button for other roles.
bool canErase(String? role) => role == 'BUSINESS_OWNER' || role == 'BUSINESS_ADMIN';

class _EraseDialog extends ConsumerStatefulWidget {
  final String customerId;
  const _EraseDialog({required this.customerId});
  @override
  ConsumerState<_EraseDialog> createState() => _EraseState();
}

class _EraseState extends ConsumerState<_EraseDialog> {
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.privacyDelete),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l.privacyDeleteWarn), FormError(_error)]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          key: const Key('confirmErase'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white, minimumSize: const Size(96, 44)),
          onPressed: _busy ? null : () async {
            setState(() { _busy = true; _error = null; });
            final err = await attempt(context, () => ref.read(bookingActionsProvider).anonymizeCustomer(widget.customerId));
            if (!context.mounted) return;
            if (err == null) { Navigator.pop(context); } else { setState(() { _busy = false; _error = err; }); }
          },
          child: Text(l.privacyConfirm),
        ),
      ],
    );
  }
}

class _TagsDialog extends ConsumerStatefulWidget {
  final Customer customer;
  const _TagsDialog({required this.customer});
  @override
  ConsumerState<_TagsDialog> createState() => _TagsState();
}

class _TagsState extends ConsumerState<_TagsDialog> {
  late final _text = TextEditingController(text: widget.customer.tags.join(', '));
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.tagsTitle),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(key: const Key('tagsField'), controller: _text, decoration: InputDecoration(labelText: l.tagsTitle, helperText: l.tagsHint)),
        FormError(_error),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          key: const Key('saveTags'),
          onPressed: _busy ? null : () async {
            final tags = _text.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
            if (tags.any((t) => t.length > 30) || tags.length > 10) { setState(() => _error = l.tagsInvalid); return; }
            setState(() { _busy = true; _error = null; });
            final err = await attempt(context, () => ref.read(bookingActionsProvider).setCustomerTags(widget.customer.id, tags));
            if (!context.mounted) return;
            if (err == null) { Navigator.pop(context); } else { setState(() { _busy = false; _error = err; }); }
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}
