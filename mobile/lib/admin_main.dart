import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin/admin_app.dart';

/// Platform administration entry point (Flutter Web, desktop-first):
///   flutter build web -t lib/admin_main.dart --dart-define=ORLEU_API_URL=https://api.example
void main() => runApp(const ProviderScope(child: AdminApp()));
