import 'package:flutter/material.dart';

import '../design/tokens.dart';
import 'brand.dart';
import 'pressable.dart';

class NavItem {
  final IconData icon, selectedIcon;
  final String label;
  const NavItem(this.icon, this.selectedIcon, this.label);
}

/// Desktop/tablet navigation: full sidebar (labels) on expanded widths, icon rail otherwise.
class AppSidebar extends StatelessWidget {
  final List<NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final String title;
  final bool extended;
  const AppSidebar({super.key, required this.items, required this.selectedIndex, required this.onSelect, required this.title, this.extended = true});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final dark = context.isDark;
    final width = extended ? 248.0 : 84.0;
    return Container(
      width: width,
      decoration: BoxDecoration(color: s.surface, border: Border(right: BorderSide(color: s.outlineVariant))),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: extended ? AppSpacing.md : AppSpacing.sm + 4, vertical: AppSpacing.lg),
          child: Column(crossAxisAlignment: extended ? CrossAxisAlignment.stretch : CrossAxisAlignment.center, children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: extended ? AppSpacing.sm : 0),
              child: Row(mainAxisAlignment: extended ? MainAxisAlignment.start : MainAxisAlignment.center, children: [
                const LogoMark(size: 40),
                if (extended) ...[
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                ],
              ]),
            ),
            const SizedBox(height: AppSpacing.lg + 8),
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs + 2),
                child: Semantics(
                  selected: i == selectedIndex, button: true, label: items[i].label,
                  child: Tooltip(
                    message: extended ? '' : items[i].label,
                    child: Pressable(
                      child: Material(
                        color: i == selectedIndex ? (dark ? s.primaryContainer : AppColors.primaryDark) : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          onTap: () => onSelect(i),
                          child: Container(
                            height: 48, padding: EdgeInsets.symmetric(horizontal: extended ? AppSpacing.md : 0),
                            alignment: extended ? Alignment.centerLeft : Alignment.center,
                            child: Row(mainAxisSize: extended ? MainAxisSize.max : MainAxisSize.min, children: [
                              Icon(i == selectedIndex ? items[i].selectedIcon : items[i].icon, size: AppIconSize.lg - 2,
                                  color: i == selectedIndex ? (dark ? s.primary : AppColors.accentLime) : s.onSurfaceVariant),
                              if (extended) ...[
                                const SizedBox(width: AppSpacing.sm + 4),
                                Expanded(child: Text(items[i].label, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: t.labelLarge?.copyWith(color: i == selectedIndex ? (dark ? s.onSurface : Colors.white) : s.onSurfaceVariant, fontWeight: i == selectedIndex ? FontWeight.w700 : FontWeight.w500))),
                              ],
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
