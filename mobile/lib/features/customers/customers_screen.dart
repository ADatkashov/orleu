import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/repository.dart';
import '../../core/design/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../l10n/gen/app_localizations.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});
  @override
  ConsumerState<CustomersScreen> createState() => _State();
}

class _State extends ConsumerState<CustomersScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final res = ref.watch(customersProvider(_q));
    final tags = ref.watch(customerTagsProvider).value ?? const [];
    final selected = ref.watch(customerTagFilterProvider);
    final gutter = AppSpacing.gutter(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.navCustomers), actions: [
        Padding(
          padding: EdgeInsets.only(right: gutter - 4),
          child: AppIconButton(key: const Key('importCsv'), tooltip: l.importNav, icon: Icons.upload_file_outlined, onPressed: () => context.push('/customers/import')),
        ),
      ]),
      body: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, AppSpacing.xs, gutter, AppSpacing.sm + 4),
          child: SearchField(hint: l.searchCustomers, onChanged: (v) => setState(() => _q = v)),
        ),
        if (tags.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal, padding: EdgeInsets.symmetric(horizontal: gutter),
              children: [
                for (final t in tags) Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: AppFilterChip(
                    key: Key('tagFilter-${t.tag}'), label: '${t.tag} · ${t.customers}', selected: selected == t.tag,
                    onSelected: (on) => ref.read(customerTagFilterProvider.notifier).select(on ? t.tag : null),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: res.when(
            loading: () => const SkeletonList(),
            error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(customersProvider)),
            data: (list) => list.isEmpty
                ? EmptyState(icon: Icons.people_outline_rounded, text: l.noCustomers)
                : RefreshIndicator(
                    onRefresh: () async => ref.invalidate(customersProvider),
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(gutter, AppSpacing.md, gutter, AppSpacing.xl),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm + 2),
                      itemBuilder: (_, i) {
                        final c = list[i];
                        return Entrance(index: i, child: CustomerCard(key: Key('customer-${c.id}'), customer: c, onTap: () => context.push('/customers/${c.id}')));
                      },
                    ),
                  ),
          ),
        ),
      ]),
    );
  }
}
