import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

// Public publishable key — safe to embed in client code, access is
// governed by the project's row level security policies, not this key.
const supabaseUrl = 'https://oeelhfvbxtrmvejllwjy.supabase.co';
const supabasePublishableKey = 'sb_publishable_-ObD45UQ9BiZTleA3jrg9w_JdR8b_7W';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey);

  runApp(
    // ProviderScope must wrap the whole app exactly once — it holds the
    // container for every provider defined across all feature modules.
    const ProviderScope(child: HiddenGemsApp()),
  );
}
