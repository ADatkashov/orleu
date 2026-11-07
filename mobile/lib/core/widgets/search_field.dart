import 'dart:async';

import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// Search box with a clear button and built-in debounce ([onChanged] fires after [debounce]).
class SearchField extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final Duration debounce;
  final Key? fieldKey;
  const SearchField({super.key, required this.hint, required this.onChanged, this.debounce = const Duration(milliseconds: 350), this.fieldKey});
  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  final _c = TextEditingController();
  Timer? _t;

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _emit(String v) {
    _t?.cancel();
    _t = Timer(widget.debounce, () => widget.onChanged(v.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: widget.fieldKey, controller: _c, textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search_rounded, size: AppIconSize.lg),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _c,
          builder: (_, v, _) => v.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(icon: const Icon(Icons.close_rounded, size: AppIconSize.md), onPressed: () { _c.clear(); _t?.cancel(); widget.onChanged(''); }),
        ),
      ),
      onChanged: _emit,
    );
  }
}

class AppFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  const AppFilterChip({super.key, required this.label, required this.selected, required this.onSelected});
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final dark = context.isDark;
    return FilterChip(
      label: Text(label), selected: selected, onSelected: onSelected,
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: selected ? (dark ? s.onPrimaryContainer : AppColors.accentLime) : s.onSurface),
    );
  }
}
