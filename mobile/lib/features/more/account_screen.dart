import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/auth_controller.dart';
import '../../core/data/models.dart';
import '../../core/data/repository.dart';
import '../../core/design/tokens.dart';
import '../../core/widgets/common.dart';
import '../../l10n/gen/app_localizations.dart';
import '../setup/setup_common.dart';

/// Change password and manage signed-in devices. The server ends every other session when the password changes.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});
  @override
  ConsumerState<AccountScreen> createState() => _AccountState();
}

class _AccountState extends ConsumerState<AccountScreen> {
  final _current = TextEditingController(), _next = TextEditingController(), _repeat = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _change() async {
    final l = AppLocalizations.of(context);
    if (_current.text.isEmpty) { setState(() => _error = l.validationRequired); return; }
    if (_next.text.length < 10) { setState(() => _error = l.validationPasswordShort); return; }
    if (_next.text != _repeat.text) { setState(() => _error = l.passwordsDiffer); return; }
    setState(() { _busy = true; _error = null; });
    final err = await attempt(context, () => ref.read(authControllerProvider.notifier).changePassword(_current.text, _next.text));
    if (!mounted) return;
    setState(() { _busy = false; _error = err; });
    if (err == null) {
      _current.clear(); _next.clear(); _repeat.clear();
      ref.invalidate(sessionsProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.passwordChanged)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final sessions = ref.watch(sessionsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.accountNav)),
      body: ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
        Text(l.changePassword, style: t.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        TextField(key: const Key('current'), controller: _current, obscureText: true, decoration: InputDecoration(labelText: l.currentPassword)),
        const SizedBox(height: AppSpacing.sm),
        TextField(key: const Key('next'), controller: _next, obscureText: true, decoration: InputDecoration(labelText: l.newPassword)),
        const SizedBox(height: AppSpacing.sm),
        TextField(key: const Key('repeat'), controller: _repeat, obscureText: true, decoration: InputDecoration(labelText: l.confirmPassword)),
        FormError(_error),
        const SizedBox(height: AppSpacing.md),
        FilledButton(key: const Key('change'), onPressed: _busy ? null : _change, child: Text(l.changePassword)),
        const SizedBox(height: AppSpacing.lg),
        Text(l.sessionsTitle, style: t.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(l.sessionsNote, style: t.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        sessions.when(
          loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.md), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(sessionsProvider)),
          data: (list) => list.isEmpty
              ? Text(l.sessionsNone)
              : Column(children: [for (final s in list) _SessionTile(s)]),
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          key: const Key('logout-all'),
          icon: const Icon(Icons.logout),
          label: Text(l.signOutEverywhere),
          onPressed: () => guarded(context, () => ref.read(authControllerProvider.notifier).logoutEverywhere()),
        ),
      ]),
    );
  }
}

class _SessionTile extends ConsumerWidget {
  final DeviceSession s;
  const _SessionTile(this.s);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final ua = s.userAgent;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.devices_outlined),
        title: Text(ua == null || ua.isEmpty ? l.sessionUnknownDevice : ua, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(l.sessionSince(DateFormat('dd.MM.yyyy HH:mm').format(s.createdAt.toLocal()))),
        trailing: TextButton(key: Key('revoke-${s.id}'), onPressed: () => guarded(context, () => revokeSession(ref, s.id)), child: Text(l.sessionRevoke)),
      ),
    );
  }
}
