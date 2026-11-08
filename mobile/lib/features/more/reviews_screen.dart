import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/models.dart';
import '../../core/data/repository.dart';
import '../../core/design/tokens.dart';
import '../../core/tz.dart';
import '../../core/widgets/common.dart';
import '../../l10n/gen/app_localizations.dart';
import '../setup/setup_common.dart';

/// Measured average and distribution plus the reviews themselves. Reviews come only from completed visits (server-enforced).
class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final zone = ref.watch(businessZoneProvider);
    final data = ref.watch(reviewsProvider);
    final role = ref.watch(myRoleProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(l.reviewsNav)),
      body: data.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(reviewsProvider)),
        data: (d) {
          final (sum, items) = d;
          if (sum.count == 0) return EmptyState(icon: Icons.star_outline, text: l.reviewsNone);
          final maxCount = sum.distribution.fold<int>(1, (a, v) => v > a ? v : a);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(reviewsProvider),
            child: ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.reviewsAverage, style: t.textTheme.bodySmall),
                      Text(sum.average!.toStringAsFixed(1), key: const Key('avg'), style: t.textTheme.headlineMedium),
                      Text(l.reviewsCount(sum.count), style: t.textTheme.bodySmall),
                    ]),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(child: Column(children: [
                      for (var star = 5; star >= 1; star--) Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(children: [
                          SizedBox(width: 16, child: Text('$star', style: t.textTheme.bodySmall)),
                          Expanded(child: LinearProgressIndicator(value: sum.distribution[star - 1] / maxCount, minHeight: 8, borderRadius: BorderRadius.circular(4))),
                          SizedBox(width: 28, child: Text('${sum.distribution[star - 1]}', textAlign: TextAlign.end, style: t.textTheme.bodySmall)),
                        ]),
                      ),
                    ])),
                  ]),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(l.reviewsNote, style: t.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              for (final r in items) Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Semantics(label: '${r.rating}/5', child: Text('★' * r.rating + '☆' * (5 - r.rating), style: t.textTheme.titleMedium?.copyWith(color: context.palette.warningFg))),
                      const Spacer(),
                      Text(DateFormat('dd.MM.yyyy').format(wallFromInstant(r.createdAt, zone)), style: t.textTheme.bodySmall),
                    ]),
                    Text('${r.customerName} · ${r.serviceName}', style: t.textTheme.bodySmall),
                    if (r.comment != null && r.comment!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: AppSpacing.xs), child: Text(r.comment!)),
                    if (r.hidden) Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(l.reviewHidden(r.hiddenReason ?? ''), key: Key('hidden-${r.id}'), style: TextStyle(color: context.palette.warningFg)),
                    ),
                    if (r.reply != null) Container(
                      key: Key('reply-${r.id}'), margin: const EdgeInsets.only(top: AppSpacing.sm), padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(border: Border(left: BorderSide(color: t.colorScheme.primary, width: 3))),
                      child: Text(r.reply!),
                    ),
                    if (!r.hidden && (role == 'BUSINESS_OWNER' || role == 'BUSINESS_ADMIN')) Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(children: [
                        if (r.reply != null) TextButton(key: Key('removeReply-${r.id}'), onPressed: () => guarded(context, () => replyToReview(ref, r.id, null)), child: Text(l.reviewReplyRemove)),
                        TextButton(key: Key('reply-btn-${r.id}'), onPressed: () => showDialog(context: context, builder: (_) => _ReplyDialog(review: r)), child: Text(r.reply == null ? l.reviewReply : l.edit)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _ReplyDialog extends ConsumerStatefulWidget {
  final ReviewItem review;
  const _ReplyDialog({required this.review});
  @override
  ConsumerState<_ReplyDialog> createState() => _ReplyState();
}

class _ReplyState extends ConsumerState<_ReplyDialog> {
  late final _text = TextEditingController(text: widget.review.reply ?? '');
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.reviewReply),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.reviewReplyNote, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        TextField(key: const Key('replyText'), controller: _text, maxLines: 4, maxLength: 1000, decoration: InputDecoration(labelText: l.reviewReply)),
        FormError(_error),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          key: const Key('sendReply'), style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: _busy ? null : () async {
            final text = _text.text.trim();
            if (text.isEmpty) { setState(() => _error = l.validationRequired); return; }
            setState(() { _busy = true; _error = null; });
            final err = await attempt(context, () => replyToReview(ref, widget.review.id, text));
            if (!context.mounted) return;
            if (err == null) { Navigator.pop(context); } else { setState(() { _busy = false; _error = err; }); }
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}
