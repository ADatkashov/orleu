import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/data/repository.dart';
import '../../core/design/tokens.dart';
import '../../core/errors.dart';
import '../../l10n/gen/app_localizations.dart';

/// Saves bytes through the platform "save file" dialog (browser download on web). Replaced in tests.
final csvSaverProvider = Provider<Future<bool> Function(String name, Uint8List bytes)>((ref) => (name, bytes) async {
      final uri = await FilePicker.saveFile(fileName: name, bytes: bytes, mimeType: 'text/csv');
      return uri != null;
    });

/// Ledger CSV for the accountant, for the period selected above. Only shown to roles the server allows (it enforces the permission itself).
class ExportSection extends ConsumerStatefulWidget {
  const ExportSection({super.key});
  @override
  ConsumerState<ExportSection> createState() => _State();
}

class _State extends ConsumerState<ExportSection> {
  bool _semicolon = true, _busy = false;
  String? _message;
  bool _error = false;

  Future<void> _export() async {
    final l = AppLocalizations.of(context);
    setState(() { _busy = true; _message = null; });
    try {
      final f = await ref.read(bookingActionsProvider).exportLedger(days: ref.read(reportDaysProvider), semicolon: _semicolon);
      final saved = await ref.read(csvSaverProvider)(f.name, f.bytes);
      if (mounted) setState(() { _message = saved ? l.exportSaved : l.exportCancelled; _error = false; });
    } catch (e) {
      final status = ApiError.from(e).status;
      if (mounted) setState(() { _message = status == 403 ? l.errExportForbidden : errorText(context, e); _error = true; });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final role = ref.watch(myRoleProvider).value;
    if (!canExportFinance(role)) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.exportTitle, style: t.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(l.exportNote, style: t.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<bool>(
            key: const Key('delimiter'),
            showSelectedIcon: false,
            segments: [ButtonSegment(value: false, label: Text(l.exportComma)), ButtonSegment(value: true, label: Text(l.exportSemicolon))],
            selected: {_semicolon},
            onSelectionChanged: (s) => setState(() => _semicolon = s.first),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(key: const Key('exportCsv'), style: FilledButton.styleFrom(minimumSize: const Size(96, 44)), icon: const Icon(Icons.download), label: Text(l.exportButton), onPressed: _busy ? null : _export),
          if (_message != null) Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(_message!, key: const Key('exportMessage'), style: TextStyle(color: _error ? t.colorScheme.error : null)),
          ),
        ]),
      ),
    );
  }
}
