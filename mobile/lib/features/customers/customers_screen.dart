import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/repository.dart';
import '../../core/design/tokens.dart';
import '../../core/widgets/common.dart';
import '../../l10n/gen/app_localizations.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});
  @override
  ConsumerState<CustomersScreen> createState() => _State();
}

class _State extends ConsumerState<CustomersScreen> {
  String _q = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final res = ref.watch(customersProvider(_q));
    return Scaffold(
      appBar: AppBar(title: Text(l.navCustomers)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
          child: TextField(
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l.searchCustomers),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _q = v.trim()));
            },
          ),
        ),
        Expanded(
          child: res.when(
            loading: () => const SkeletonList(),
            error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(customersProvider)),
            data: (list) => list.isEmpty
                ? EmptyState(icon: Icons.people_outline, text: l.noCustomers)
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) {
                      final c = list[i];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Text(c.fullName.isEmpty ? '?' : c.fullName[0].toUpperCase())),
                          title: Text(c.fullName),
                          subtitle: Text(c.phone),
                          trailing: c.blocked ? const Icon(Icons.block, color: AppColors.danger) : null,
                        ),
                      );
                    },
                  ),
          ),
        ),
      ]),
    );
  }
}
