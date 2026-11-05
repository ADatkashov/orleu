import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/auth_controller.dart';
import '../../core/design/tokens.dart';
import '../../core/errors.dart';
import '../../l10n/gen/app_localizations.dart';

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class _AuthScaffold extends StatelessWidget {
  final List<Widget> children;
  const _AuthScaffold({required this.children});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(l.appName, style: t.textTheme.headlineMedium?.copyWith(color: t.colorScheme.primary, letterSpacing: 4)),
                const SizedBox(height: AppSpacing.xs),
                Text(l.tagline, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.xl),
                ...children,
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginState();
}

class _LoginState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(), _password = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(authControllerProvider.notifier).login(_email.text.trim(), _password.text);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _AuthScaffold(children: [
      Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextFormField(
            controller: _email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(labelText: l.email),
            validator: (v) => v == null || !_emailRe.hasMatch(v.trim()) ? l.validationEmail : null,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _password, obscureText: true, autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(labelText: l.password),
            validator: (v) => v == null || v.isEmpty ? l.validationRequired : null,
            onFieldSubmitted: (_) => _submit(),
          ),
          if (_error != null) Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(_error!, key: const Key('authError'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: _busy ? null : _submit, child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l.signIn)),
          TextButton(onPressed: () => context.go('/register'), child: Text(l.noAccountYet)),
        ]),
      ),
    ]);
  }
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterState();
}

class _RegisterState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _email = TextEditingController(), _password = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(authControllerProvider.notifier).register(_email.text.trim(), _password.text, _name.text.trim());
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _AuthScaffold(children: [
      Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextFormField(controller: _name, decoration: InputDecoration(labelText: l.fullName),
              validator: (v) => v == null || v.trim().isEmpty ? l.validationRequired : null),
          const SizedBox(height: AppSpacing.md),
          TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: l.email),
              validator: (v) => v == null || !_emailRe.hasMatch(v.trim()) ? l.validationEmail : null),
          const SizedBox(height: AppSpacing.md),
          TextFormField(controller: _password, obscureText: true, decoration: InputDecoration(labelText: l.password),
              validator: (v) => v == null || v.length < 10 ? l.validationPasswordShort : null),
          if (_error != null) Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(_error!, key: const Key('authError'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: _busy ? null : _submit, child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l.createAccount)),
          TextButton(onPressed: () => context.go('/login'), child: Text(l.haveAccount)),
        ]),
      ),
    ]);
  }
}
