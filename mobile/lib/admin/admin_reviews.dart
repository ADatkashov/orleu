import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/data/auth_controller.dart';
import '../core/design/tokens.dart';
import 'admin_data.dart';
import 'admin_widgets.dart';

class AdminReview {
  final String id, businessName, customerName;
  final int rating;
  final String? comment, hiddenReason, reply;
  final bool hidden;
  final DateTime createdAt;
  const AdminReview({required this.id, required this.businessName, required this.customerName, required this.rating, this.comment, this.hiddenReason, this.reply, required this.hidden, required this.createdAt});
  factory AdminReview.fromJson(Map<String, dynamic> j) => AdminReview(
      id: j['id'], businessName: j['businessName'] ?? '', customerName: j['customerName'] ?? '', rating: j['rating'], comment: j['comment'], hiddenReason: j['hiddenReason'],
      reply: j['reply'], hidden: j['hidden'] == true, createdAt: DateTime.parse(j['createdAt']).toLocal());
}

typedef ReviewQuery = ({bool hidden, int page});

final adminReviewsProvider = FutureProvider.autoDispose.family<List<AdminReview>, ReviewQuery>((ref, k) async {
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/admin/reviews', queryParameters: {'hidden': k.hidden, 'page': k.page, 'size': adminPageSize}));
  return [for (final e in (r.data as List)) AdminReview.fromJson(e)];
});

Future<void> hideReview(WidgetRef ref, String id, String reason) async {
  await ref.read(apiClientProvider).run((d) => d.post('/api/v1/admin/reviews/$id/hide', data: {'reason': reason}));
  ref.invalidate(adminReviewsProvider);
}

Future<void> unhideReview(WidgetRef ref, String id) async {
  await ref.read(apiClientProvider).run((d) => d.post('/api/v1/admin/reviews/$id/unhide'));
  ref.invalidate(adminReviewsProvider);
}

/// Moderation: platform support can hide an abusive or fraudulent review (reason required, audited, reversible). Businesses cannot.
class AdminReviewsScreen extends ConsumerStatefulWidget {
  const AdminReviewsScreen({super.key});
  @override
  ConsumerState<AdminReviewsScreen> createState() => _State();
}

class _State extends ConsumerState<AdminReviewsScreen> {
  bool _hidden = false;
  int _page = 0;
  String? _error;

  Future<void> _hide(AdminReview r) async {
    final reason = TextEditingController();
    String? err;
    final done = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        title: const Text(S.hide),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(key: const Key('hideReason'), controller: reason, maxLength: 300, decoration: const InputDecoration(labelText: S.hideReason)),
          InlineError(err),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text(S.cancel)),
          FilledButton(key: const Key('confirmHide'), onPressed: () async {
            final e = await adminAttempt(() => hideReview(ref, r.id, reason.text.trim()));
            if (e == null) { if (ctx.mounted) Navigator.pop(ctx, true); } else { setD(() => err = e); }
          }, child: const Text(S.confirm)),
        ],
      )),
    );
    if (done == true && mounted) setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final canModify = ref.watch(adminMeProvider).value?.canSeePersonalData ?? false;
    final res = ref.watch(adminReviewsProvider((hidden: _hidden, page: _page)));
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(S.reviews, style: t.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.md),
        Wrap(spacing: AppSpacing.sm, children: [
          ChoiceChip(key: const Key('filter-all'), label: const Text('All'), selected: !_hidden, onSelected: (_) => setState(() { _hidden = false; _page = 0; })),
          ChoiceChip(key: const Key('filter-hidden'), label: const Text(S.onlyHidden), selected: _hidden, onSelected: (_) => setState(() { _hidden = true; _page = 0; })),
        ]),
        InlineError(_error),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: res.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AdminError(error: e, onRetry: () => ref.invalidate(adminReviewsProvider)),
            data: (list) => Column(children: [
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text(S.empty))
                    : ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (_, i) {
                          final r = list[i];
                          return ListTile(
                            key: Key('review-${r.id}'),
                            title: Text('${'★' * r.rating}${'☆' * (5 - r.rating)}  ${r.businessName}', overflow: TextOverflow.ellipsis),
                            subtitle: Text([DateFormat('yyyy-MM-dd').format(r.createdAt), r.customerName, if (r.comment != null) r.comment!, if (r.hidden) 'Hidden: ${r.hiddenReason}'].join(' · ')),
                            isThreeLine: r.comment != null,
                            trailing: Wrap(spacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
                              if (r.hidden) const Pill('HIDDEN', AppColors.danger),
                              if (canModify) r.hidden
                                  ? TextButton(key: Key('unhide-${r.id}'), onPressed: () async { final e = await adminAttempt(() => unhideReview(ref, r.id)); if (mounted) setState(() => _error = e); }, child: const Text(S.unhide))
                                  : TextButton(key: Key('hide-${r.id}'), onPressed: () => _hide(r), child: const Text(S.hide)),
                            ]),
                          );
                        },
                      ),
              ),
              Pager(page: _page, hasNext: list.length == adminPageSize, onPage: (p) => setState(() => _page = p)),
            ]),
          ),
        ),
      ]),
    );
  }
}
