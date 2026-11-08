# Redesign screenshots (fake data)

Rendered by `mobile/test/tool/screenshots_test.dart` (real Inter font and icons, in-memory fake API, light and dark themes):

```
cd mobile
ORLEU_SHOT_DIR=../docs/screenshots/redesign flutter test test/tool/screenshots_test.dart
```

Phone 390x844 @2x unless the name says otherwise: `home-*`, `calendar-*`, `booking-sheet-*`, `new-booking-*`, `customers-*`, `profile-*`,
`finance-*`, `more-*`, `notifications-*`, `services-*`, `employees-*`, `branches-*`, `reviews-*`, `promos-*`, `giftcards-*`, `support-*`,
`account-*`, `login-*`, `register-*`. Other sizes: `home-tablet` (768x1024), `home-desktop` (1280x860), `home-320-kk` (320x640, Kazakh),
`admin-1280` / `admin-390` (admin console).
The older demo-app screenshots live one directory up. Rendered by a test renderer: soft shadows look flatter than on a device.
