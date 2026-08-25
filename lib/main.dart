import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'shared/services/hidden_gem_scoring.dart';

// Public publishable key — safe to embed in client code, access is
// governed by the project's row level security policies, not this key.
const supabaseUrl = 'https://oeelhfvbxtrmvejllwjy.supabase.co';
const supabasePublishableKey = 'sb_publishable_-ObD45UQ9BiZTleA3jrg9w_JdR8b_7W';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey);

  // Module 1: pull the Hidden Gem Scoring Engine's weights from Supabase
  // before the first frame — every module that scores a place (itinerary
  // planning, destination exploration, this app's own discovery feed)
  // reads HiddenGemScoring's static fields, so this one call is what makes
  // NFR5.1 ("weights configurable without a code change") apply
  // app-wide. Best-effort: on failure the compiled-in defaults stand in,
  // so a slow/offline start never blocks the app.
  unawaited(HiddenGemScoring.loadConfig());

  runApp(
    // ProviderScope must wrap the whole app exactly once — it holds the
    // container for every provider defined across all feature modules.
    const ProviderScope(child: HiddenGemsApp()),
  );
}
