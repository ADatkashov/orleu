# ORLEU design system (Flutter app and admin console)

Single source of truth: `mobile/lib/core/design/` (tokens + theme) and `mobile/lib/core/widgets/` (components).
Screens import `core/widgets/widgets.dart` and never hardcode colors, radii or text styles.

## Tokens (`tokens.dart`)
- **Colors**: `AppColors` (brand palette, light + dark), `AppPalette` theme extension (`context.palette`) for semantic roles that differ by theme:
  success / warning / danger / info soft tints with AA foregrounds, hero gradient, chart colors.
- **Spacing** 8px grid (`AppSpacing`), **radii** (`AppRadius`: control 12, card 16, hero 24, sheet 28), **icon sizes**, **control sizes**
  (min tap target 48), **motion** (`AppMotion` 120/220/420 ms), **breakpoints** (`AppBreakpoints`: compact < 600, wide >= 840, expanded >= 1200),
  **shadows** (`AppShadows`, none in dark mode: surfaces are separated by tone).
- **Typography** (`theme.dart`): Inter (static 400-800, subset: Latin + Cyrillic incl. Kazakh letters + tenge sign; SIL OFL, `assets/fonts/`).

## Components (`core/widgets/`)
`AppCard`, `PrimaryButton` / `SecondaryButton` / `AppIconButton`, `StatCard` (+ compact `StatTile`), `StatusBadge` / `BookingStatusBadge`,
`SectionHeader`, `SearchField` (debounced) / `AppFilterChip`, `AppAvatar`, `BookingCard` / `CustomerCard` / `ServiceCard` / `EmployeeCard`,
`SettingsGroup` / `SettingsTile`, `DateSelector`, `AnalyticsBarChart` (real series only, animated), `EmptyState` / `ErrorState` / `LoadingState` /
`SkeletonList` / `SkeletonBox` (shimmer, static with "reduce motion"), `showConfirmationDialog`, `AppSidebar` (sidebar or icon rail), `LogoMark`,
`Pressable` (press feedback) and `Entrance` (staggered fade-in). The legacy names `ErrorRetry`, `StatusChip`, `StatTile` still exist.

## Rules
- Text on a soft tint uses the matching `*Fg` (WCAG AA is asserted per theme in `test/design_system_test.dart`).
- User-visible strings come from the arb files (kk / ru / en); widgets must tolerate long Kazakh and Russian labels (ellipsis / wrap, no fixed widths).
- Errors inside bottom sheets and dialogs stay inline (see CLAUDE.md).

## Reviewing screens without a device
`ORLEU_SHOT_DIR=/some/dir flutter test test/tool/screenshots_test.dart` renders the main screens (light, dark, phone, tablet, desktop, 320px Kazakh,
admin console) to PNGs with the real font and icons. It is skipped when the variable is not set.
