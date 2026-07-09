import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  runApp(
    // ProviderScope must wrap the whole app exactly once — it holds the
    // container for every provider defined across all feature modules.
    const ProviderScope(child: HiddenGemsApp()),
  );
}