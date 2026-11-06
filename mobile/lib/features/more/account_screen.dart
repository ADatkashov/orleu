import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        const _MfaCard(),
        const SizedBox(height: AppSpacing.lg),
        const _HistoryCard(),
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

/// Two-factor authentication (TOTP): shows the status, runs the enrolment (setup key -> first code -> one-time recovery codes) and the disabling.
class _MfaCard extends ConsumerStatefulWidget {
  const _MfaCard();
  @override
  ConsumerState<_MfaCard> createState() => _MfaState();
}

class _MfaState extends ConsumerState<_MfaCard> {
  String? _secret, _error;
  List<String>? _recovery;
  final _code = TextEditingController();
  bool _busy = false;

  Future<void> _start() async {
    setState(() { _busy = true; _error = null; });
    String? secret;
    final err = await attempt(context, () async { secret = (await MfaApi(ref).setup()).secret; });
    if (!mounted) return;
    setState(() { _busy = false; _error = err; _secret = secret; _code.clear(); });
  }

  Future<void> _confirm() async {
    setState(() { _busy = true; _error = null; });
    List<String>? codes;
    final err = await attempt(context, () async { codes = await MfaApi(ref).enable(_code.text.trim()); });
    if (!mounted) return;
    setState(() { _busy = false; _error = err; if (err == null) { _secret = null; _recovery = codes; } });
  }

  Future<void> _disable() async {
    await showDialog<void>(context: context, builder: (_) => const _DisableMfaDialog());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final status = ref.watch(mfaStatusProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.mfaTitle, style: t.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(l.mfaIntro, style: t.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          if (_recovery != null) ...[
            Text(l.mfaRecoveryTitle, style: t.textTheme.titleSmall),
            Text(l.mfaRecoveryNote, style: t.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            SelectableText(_recovery!.join('\n'), key: const Key('recoveryCodes'), style: const TextStyle(fontFamily: 'monospace')),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(key: const Key('recoverySaved'), style: FilledButton.styleFrom(minimumSize: const Size(96, 44)), onPressed: () => setState(() => _recovery = null), child: Text(l.mfaSaved)),
          ] else if (_secret != null) ...[
            Text(l.mfaSetupKey, style: t.textTheme.titleSmall),
            SelectableText(_secret!, key: const Key('setupKey'), style: const TextStyle(fontFamily: 'monospace', fontSize: 16)),
            Text(l.mfaSetupHint, style: t.textTheme.bodySmall),
            TextButton.icon(icon: const Icon(Icons.copy, size: 18), label: Text(l.mfaCopy), onPressed: () => Clipboard.setData(ClipboardData(text: _secret!))),
            TextField(key: const Key('enableCode'), controller: _code, keyboardType: TextInputType.number, maxLength: 6, decoration: InputDecoration(labelText: l.mfaCode)),
            FormError(_error),
            FilledButton(key: const Key('mfaConfirm'), style: FilledButton.styleFrom(minimumSize: const Size(96, 44)), onPressed: _busy ? null : _confirm, child: Text(l.mfaConfirm)),
          ] else
            status.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(mfaStatusProvider)),
              data: (s) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.enabled ? l.mfaOn(s.recoveryCodesLeft) : l.mfaOff, key: const Key('mfaStatus'), style: t.textTheme.titleSmall?.copyWith(color: s.enabled ? AppColors.success : null)),
                FormError(_error),
                const SizedBox(height: AppSpacing.sm),
                s.enabled
                    ? OutlinedButton(key: const Key('mfaDisable'), style: OutlinedButton.styleFrom(minimumSize: const Size(96, 44)), onPressed: _disable, child: Text(l.mfaDisable))
                    : FilledButton(key: const Key('mfaEnable'), style: FilledButton.styleFrom(minimumSize: const Size(96, 44)), onPressed: _busy ? null : _start, child: Text(l.mfaEnable)),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _DisableMfaDialog extends ConsumerStatefulWidget {
  const _DisableMfaDialog();
  @override
  ConsumerState<_DisableMfaDialog> createState() => _DisableState();
}

class _DisableState extends ConsumerState<_DisableMfaDialog> {
  final _password = TextEditingController(), _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.mfaDisable),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(l.mfaDisableHint),
        TextField(key: const Key('disablePassword'), controller: _password, obscureText: true, decoration: InputDecoration(labelText: l.currentPassword)),
        TextField(key: const Key('disableCode'), controller: _code, decoration: InputDecoration(labelText: l.mfaCode)),
        FormError(_error),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          key: const Key('confirmDisable'),
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: _busy ? null : () async {
            setState(() { _busy = true; _error = null; });
            final err = await attempt(context, () => MfaApi(ref).disable(_password.text, _code.text.trim()));
            if (!context.mounted) return;
            if (err == null) { Navigator.pop(context); } else { setState(() { _busy = false; _error = err; }); }
          },
          child: Text(l.mfaDisable),
        ),
      ],
    );
  }
}

/// Recent sign-ins of this account with an alert for failed attempts and new devices.
class _HistoryCard extends ConsumerWidget {
  const _HistoryCard();

  String _outcome(AppLocalizations l, LoginEvent e) => switch (e.outcome) {
        'SUCCESS' => e.mfaUsed ? '${l.histSUCCESS} (${l.histWithCode})' : l.histSUCCESS,
        'FAILED_PASSWORD' => l.histFAILED_PASSWORD,
        'FAILED_MFA' => l.histFAILED_MFA,
        _ => l.histLOCKED,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final data = ref.watch(loginHistoryProvider);
    return data.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(loginHistoryProvider)),
      data: (h) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (h.failedSinceLastSuccess > 0 || h.newDeviceRecently)
          Card(
            key: const Key('historyAlert'),
            color: AppColors.warning.withValues(alpha: 0.12),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (h.failedSinceLastSuccess > 0) Text(l.histAlertFailed(h.failedSinceLastSuccess)),
                if (h.newDeviceRecently) Text(l.histAlertNewDevice),
                const SizedBox(height: AppSpacing.xs),
                Text(l.histAlertHint, style: t.textTheme.bodySmall),
              ]),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Text(l.histTitle, style: t.textTheme.titleMedium),
        Text(l.histNote, style: t.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.xs),
        if (h.events.isEmpty) Text(l.histNone),
        for (final e in h.events.take(10)) Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(e.outcome == 'SUCCESS' ? Icons.check_circle_outline : Icons.warning_amber_outlined, size: 18, color: e.outcome == 'SUCCESS' ? AppColors.success : AppColors.warning),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${_outcome(l, e)}${e.newDevice ? ' · ${l.histNewDevice}' : ''}', style: t.textTheme.bodyMedium?.copyWith(fontWeight: e.newDevice ? FontWeight.w700 : null)),
                Text('${DateFormat('dd.MM.yyyy HH:mm').format(e.occurredAt.toLocal())} · ${e.ip ?? '?'} · ${(e.userAgent ?? '').split(' ').first}', style: t.textTheme.bodySmall),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}
