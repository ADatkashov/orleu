import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/repository.dart';
import '../../core/design/tokens.dart';
import '../../core/errors.dart';
import '../../l10n/gen/app_localizations.dart';

/// First-run onboarding step: create the business. (Branches, services, staff and publishing are the next steps - see docs.)
class CreateBusinessScreen extends ConsumerStatefulWidget {
  const CreateBusinessScreen({super.key});
  @override
  ConsumerState<CreateBusinessScreen> createState() => _State();
}

class _State extends ConsumerState<CreateBusinessScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _slug = TextEditingController();
  String _type = 'BARBERSHOP';
  bool _busy = false;
  String? _error;

  static final _slugRe = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(bookingActionsProvider).createBusiness(_name.text.trim(), _slug.text.trim(), _type);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final types = {
      'BARBERSHOP': l.typeBarbershop, 'BEAUTY_SALON': l.typeBeautySalon, 'CLINIC': l.typeClinic,
      'FITNESS_STUDIO': l.typeFitness, 'OTHER': l.typeOther,
    };
    return Scaffold(
      appBar: AppBar(title: Text(l.createBusinessTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(l.createBusinessIntro),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(controller: _name, decoration: InputDecoration(labelText: l.businessName),
                  validator: (v) => v == null || v.trim().isEmpty ? l.validationRequired : null),
              const SizedBox(height: AppSpacing.md),
              TextFormField(controller: _slug, decoration: InputDecoration(labelText: l.bookingPageAddress, prefixText: 'orleu.app/b/'),
                  validator: (v) => v == null || v.length < 3 || v.length > 60 || !_slugRe.hasMatch(v) ? l.validationSlug : null),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _type, decoration: InputDecoration(labelText: l.businessType),
                items: [for (final e in types.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              if (_error != null) Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Text(_error!, style: TextStyle(color: context.palette.dangerFg)),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: _busy ? null : _submit, child: Text(l.create)),
            ]),
          ),
        ),
      ),
    );
  }
}
