import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/models.dart';
import '../../core/data/repository.dart';
import '../../core/design/tokens.dart';
import '../../core/errors.dart';
import '../../core/widgets/widgets.dart';
import '../../l10n/gen/app_localizations.dart';

typedef PickedCsv = ({String name, Uint8List bytes});

/// Opens the platform file picker for a CSV file. Replaced in tests.
final csvPickerProvider = Provider<Future<PickedCsv?> Function()>((ref) => () async {
      final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['csv', 'txt']);
      if (f == null) return null;
      return (name: f.name, bytes: await f.readAsBytes());
    });

/// Two steps with one server code path: a dry run shows exactly what would happen, then the user confirms.
class ImportCustomersScreen extends ConsumerStatefulWidget {
  const ImportCustomersScreen({super.key});
  @override
  ConsumerState<ImportCustomersScreen> createState() => _State();
}

class _State extends ConsumerState<ImportCustomersScreen> {
  String? _fileName, _csv, _error;
  ImportReport? _preview, _done;
  bool _busy = false;

  Future<void> _choose() async {
    final l = AppLocalizations.of(context);
    setState(() { _error = null; });
    final picked = await ref.read(csvPickerProvider)();
    if (picked == null || !mounted) return;
    String text;
    try {
      text = utf8.decode(picked.bytes);
    } on FormatException {
      setState(() { _error = l.errImportEncoding; _preview = null; _done = null; });
      return;
    }
    setState(() { _busy = true; _fileName = picked.name; _csv = text; _preview = null; _done = null; });
    try {
      final r = await ref.read(bookingActionsProvider).importCustomers(text, dryRun: true);
      if (mounted) setState(() => _preview = r);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    setState(() { _busy = true; _error = null; });
    try {
      final r = await ref.read(bookingActionsProvider).importCustomers(_csv!, dryRun: false);
      if (mounted) setState(() { _done = r; _preview = null; });
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    Widget stat(String k, int v, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [Expanded(child: Text(k)), Text('$v', style: t.textTheme.titleSmall?.copyWith(color: color))]),
        );
    final p = _preview;
    return Scaffold(
      appBar: AppBar(title: Text(l.importNav)),
      body: ListView(padding: EdgeInsets.fromLTRB(AppSpacing.gutter(context), AppSpacing.sm, AppSpacing.gutter(context), AppSpacing.xl), children: [
        AppCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: t.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(AppRadius.control)),
              child: Icon(Icons.table_chart_outlined, size: AppIconSize.md, color: t.colorScheme.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(l.importIntro, style: t.textTheme.bodyMedium)),
          ]),
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(key: const Key('chooseFile'), icon: const Icon(Icons.upload_file), label: Text(_done == null ? l.importChoose : l.importAnother), onPressed: _busy ? null : _choose),
        if (_fileName != null) Padding(padding: const EdgeInsets.only(top: AppSpacing.sm), child: Text(l.importFile(_fileName!), style: t.textTheme.bodySmall)),
        if (_busy) const Padding(padding: EdgeInsets.all(AppSpacing.md), child: LoadingState()),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: AppSpacing.md), child: Text(_error!, key: const Key('importError'), style: TextStyle(color: context.palette.dangerFg))),
        if (p != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              stat(l.importNew, p.created, color: context.palette.successFg),
              stat(l.importExisting, p.existing),
              stat(l.importDupes, p.duplicatesInFile),
              stat(l.importInvalid, p.invalid, color: p.invalid > 0 ? context.palette.warningFg : null),
            ]),
          ),
          if (p.preview.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(l.importPreviewSample, style: t.textTheme.titleSmall),
            for (final c in p.preview) Text('${c.$1} · ${c.$2}', style: t.textTheme.bodySmall),
          ],
          if (p.issues.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(l.importProblems, style: t.textTheme.titleSmall),
            for (final i in p.issues) Text(l.importRow('${i.$1}', _reason(l, i.$2)), key: Key('issue-${i.$1}'), style: t.textTheme.bodySmall),
            if (p.issuesTruncated) Text(l.importMoreProblems, style: t.textTheme.bodySmall),
          ],
          const SizedBox(height: AppSpacing.md),
          if (p.created == 0) Text(l.importNothing, key: const Key('nothingNew'))
          else FilledButton(key: const Key('confirmImport'), onPressed: _busy ? null : _confirm, child: Text(l.importConfirm('${p.created}'))),
        ],
        if (_done != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            color: context.palette.successSoft,
            child: Row(children: [
              Icon(Icons.check_circle_rounded, color: context.palette.successFg),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(child: Text(l.importDone('${_done!.created}'), key: const Key('importDone'), style: t.textTheme.titleMedium?.copyWith(color: context.palette.successFg))),
            ]),
          ),
        ],
      ]),
    );
  }

  String _reason(AppLocalizations l, String code) => switch (code) {
        'PHONE_INVALID' => l.imp_PHONE_INVALID,
        'NAME_MISSING' => l.imp_NAME_MISSING,
        'NAME_TOO_LONG' => l.imp_NAME_TOO_LONG,
        'EMAIL_INVALID' => l.imp_EMAIL_INVALID,
        'NOTES_TOO_LONG' => l.imp_NOTES_TOO_LONG,
        _ => code,
      };
}
