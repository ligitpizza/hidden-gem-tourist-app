import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../model/preference_repository.dart';
import '../model/travel_style.dart';

/// Default cooling-off window shown to a signed-out tourist or if
/// `preference_decay_config` can't be reached — mirrors that table's own
/// default so the two only ever disagree if someone deliberately
/// reconfigures it server-side.
const _defaultCoolingOffDays = 14;

/// One category's current standing on the "Your Travel Pulse" screen.
class CategoryPulse {
  final TravelStyle style;

  /// 0–1 share of the tourist's total learned affinity across their shown
  /// categories — what the radar chart plots.
  final double weight;

  final bool isCoolingOff;
  final DateTime? lastInteractedAt;

  const CategoryPulse({
    required this.style,
    required this.weight,
    required this.isCoolingOff,
    required this.lastInteractedAt,
  });
}

/// Backs the "Your Travel Pulse" screen with real data (FR3): recency-
/// weighted category affinity from `user_category_affinity` (which already
/// applies the configured decay half-life), falling back to an even split
/// across the tourist's manually-selected categories when they haven't
/// interacted with anything yet — so a brand new profile still shows
/// something instead of an empty chart.
class TravelPulseController extends ChangeNotifier {
  TravelPulseController({
    SupabaseClient? client,
    PreferenceRepository? preferenceRepository,
  })  : _client = client ?? Supabase.instance.client,
        _preferenceRepository = preferenceRepository ?? PreferenceRepository() {
    _load();
  }

  final SupabaseClient _client;
  final PreferenceRepository _preferenceRepository;

  bool isLoading = true;
  List<CategoryPulse> pulses = const [];

  Future<void> refresh() => _load();

  Future<void> _load() async {
    isLoading = true;
    notifyListeners();

    final affinity = await _loadAffinity();
    final categories = affinity.isNotEmpty
        ? (affinity.keys.toList()..sort((a, b) => affinity[b]!.score.compareTo(affinity[a]!.score)))
        : (await _preferenceRepository.load())?.categories.toList() ?? const <TravelStyle>[];
    final shown = categories.take(6).toList();

    final totalWeight = shown.fold<double>(0, (sum, s) => sum + (affinity[s]?.score ?? 0));
    final evenShare = shown.isEmpty ? 0.0 : 1 / shown.length;

    pulses = [
      for (final style in shown)
        CategoryPulse(
          style: style,
          weight: totalWeight > 0 ? (affinity[style]?.score ?? 0) / totalWeight : evenShare,
          isCoolingOff: _isCoolingOff(affinity[style]?.lastInteractedAt),
          lastInteractedAt: affinity[style]?.lastInteractedAt,
        ),
    ];

    isLoading = false;
    notifyListeners();
  }

  bool _isCoolingOff(DateTime? lastInteractedAt) {
    if (lastInteractedAt == null) return false;
    return DateTime.now().difference(lastInteractedAt).inDays >= _defaultCoolingOffDays;
  }

  Future<Map<TravelStyle, ({double score, DateTime? lastInteractedAt})>> _loadAffinity() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const {};

    try {
      final rows = await _client.from('user_category_affinity').select();
      final result = <TravelStyle, ({double score, DateTime? lastInteractedAt})>{};
      for (final row in rows as List) {
        final map = row as Map<String, dynamic>;
        final style = travelStyleFromKey(map['category'] as String?);
        if (style == null) continue;
        result[style] = (
          score: (map['affinity_score'] as num?)?.toDouble() ?? 0,
          lastInteractedAt: map['last_interacted_at'] != null
              ? DateTime.tryParse(map['last_interacted_at'] as String)
              : null,
        );
      }
      return result;
    } catch (_) {
      return const {};
    }
  }
}

final travelPulseControllerProvider = ChangeNotifierProvider.autoDispose<TravelPulseController>((ref) {
  return TravelPulseController();
});
