import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controller/traditional_food_controller.dart';
import '../model/traditional_food.dart';
import 'culture_community_routes.dart';

enum _DietaryFilter {
  all,
  vegetarian,
  allergySensitive,
}

extension _DietaryFilterX on _DietaryFilter {
  String get label {
    switch (this) {
      case _DietaryFilter.all:
        return 'All';
      case _DietaryFilter.vegetarian:
        return 'Vegetarian';
      case _DietaryFilter.allergySensitive:
        return 'Allergy-Sensitive';
    }
  }

  IconData get icon {
    switch (this) {
      case _DietaryFilter.all:
        return Icons.restaurant_outlined;
      case _DietaryFilter.vegetarian:
        return Icons.eco_outlined;
      case _DietaryFilter.allergySensitive:
        return Icons.warning_amber_rounded;
    }
  }
}

class TraditionalFoodHomeScreen extends ConsumerStatefulWidget {
  const TraditionalFoodHomeScreen({
    super.key,
  });

  @override
  ConsumerState<TraditionalFoodHomeScreen> createState() =>
      _TraditionalFoodHomeScreenState();
}

class _TraditionalFoodHomeScreenState
    extends ConsumerState<TraditionalFoodHomeScreen> {
  final TextEditingController _searchController =
  TextEditingController();

  String _searchQuery = '';

  String? _selectedState;
  String? _selectedCulturalCategory;

  _DietaryFilter _dietaryFilter = _DietaryFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // =========================================================
  // STATES
  // =========================================================

  List<String> _states(
      List<TraditionalFood> foods,
      ) {
    final states = foods
        .map(
          (food) => food.state.trim(),
    )
        .where(
          (state) => state.isNotEmpty,
    )
        .toSet()
        .toList();

    states.sort();

    return states;
  }

  // =========================================================
  // CULTURAL CATEGORIES
  // =========================================================

  List<String> _culturalCategories(
      List<TraditionalFood> foods,
      ) {
    final categories = foods
        .map(
          (food) => food.culturalCategory.trim(),
    )
        .where(
          (category) => category.isNotEmpty,
    )
        .toSet()
        .toList();

    categories.sort();

    return categories;
  }

  // =========================================================
  // DIETARY HELPERS
  // =========================================================

  bool _containsVegetarianTag(
      TraditionalFood food,
      ) {
    return food.dietaryTags.any(
          (tag) {
        final value = tag.trim().toLowerCase();

        return value == 'vegetarian' ||
            value.contains('vegetarian');
      },
    );
  }

  bool _hasAllergyInformation(
      TraditionalFood food,
      ) {
    return food.allergens.isNotEmpty ||
        (food.allergyNotes != null &&
            food.allergyNotes!.trim().isNotEmpty);
  }

  // =========================================================
  // FILTER FOOD
  // =========================================================

  List<TraditionalFood> _filteredFoods(
      List<TraditionalFood> foods,
      ) {
    final query = _searchQuery.trim().toLowerCase();

    final filtered = foods.where(
          (food) {
        // -----------------------------------------------------
        // SEARCH
        // -----------------------------------------------------

        if (query.isNotEmpty) {
          final searchableText = [
            food.name,
            food.description,
            food.culturalHistory,
            food.state,
            food.region ?? '',
            food.culturalCategory,
            ...food.ingredients,
            ...food.dietaryTags,
            ...food.allergens,
            food.allergyNotes ?? '',
          ].join(' ').toLowerCase();

          if (!searchableText.contains(query)) {
            return false;
          }
        }

        // -----------------------------------------------------
        // STATE
        // -----------------------------------------------------

        if (_selectedState != null &&
            food.state != _selectedState) {
          return false;
        }

        // -----------------------------------------------------
        // CULTURAL CATEGORY
        // -----------------------------------------------------

        if (_selectedCulturalCategory != null &&
            food.culturalCategory !=
                _selectedCulturalCategory) {
          return false;
        }

        // -----------------------------------------------------
        // DIETARY
        // -----------------------------------------------------

        switch (_dietaryFilter) {
          case _DietaryFilter.all:
            break;

          case _DietaryFilter.vegetarian:
            if (!_containsVegetarianTag(food)) {
              return false;
            }
            break;

          case _DietaryFilter.allergySensitive:
            if (!_hasAllergyInformation(food)) {
              return false;
            }
            break;
        }

        return true;
      },
    ).toList();

    filtered.sort(
          (a, b) => a.name.toLowerCase().compareTo(
        b.name.toLowerCase(),
      ),
    );

    return filtered;
  }

  // =========================================================
  // ACTIVE FILTER COUNT
  // =========================================================

  int get _activeFilterCount {
    var count = 0;

    if (_selectedState != null) {
      count++;
    }

    if (_selectedCulturalCategory != null) {
      count++;
    }

    if (_dietaryFilter != _DietaryFilter.all) {
      count++;
    }

    return count;
  }

  bool get _hasActiveFilters {
    return _activeFilterCount > 0 ||
        _searchQuery.trim().isNotEmpty;
  }

  // =========================================================
  // CLEAR ALL FILTERS
  // =========================================================

  void _clearAllFilters() {
    _searchController.clear();

    setState(() {
      _searchQuery = '';
      _selectedState = null;
      _selectedCulturalCategory = null;
      _dietaryFilter = _DietaryFilter.all;
    });
  }

  // =========================================================
  // FILTER BOTTOM SHEET
  // =========================================================

  Future<void> _showFilters(
      List<TraditionalFood> foods,
      ) async {
    final states = _states(
      foods,
    );

    final categories = _culturalCategories(
      foods,
    );

    String? temporaryState = _selectedState;

    String? temporaryCategory =
        _selectedCulturalCategory;

    var temporaryDietary = _dietaryFilter;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (
          bottomSheetContext,
          ) {
        return StatefulBuilder(
          builder: (
              context,
              setBottomSheetState,
              ) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  24,
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    // =========================================
                    // TITLE
                    // =========================================

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Filter Traditional Food',
                            style: GoogleFonts.montserrat(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setBottomSheetState(
                                  () {
                                temporaryState = null;
                                temporaryCategory = null;
                                temporaryDietary =
                                    _DietaryFilter.all;
                              },
                            );
                          },
                          child: const Text(
                            'Reset',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'Choose filters to discover traditional food that matches your interests.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // =========================================
                    // STATE
                    // =========================================

                    const _FilterSectionTitle(
                      icon: Icons.location_on_outlined,
                      title: 'Browse by State',
                    ),

                    const SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(
                          14,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: temporaryState ??
                              '__all_states__',
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(
                              value: '__all_states__',
                              child: Text(
                                'All States',
                              ),
                            ),
                            for (final state in states)
                              DropdownMenuItem(
                                value: state,
                                child: Text(
                                  state,
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            setBottomSheetState(
                                  () {
                                temporaryState =
                                value == '__all_states__'
                                    ? null
                                    : value;
                              },
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // =========================================
                    // CULTURAL CATEGORY
                    // =========================================

                    const _FilterSectionTitle(
                      icon: Icons.groups_outlined,
                      title: 'Cultural Category',
                    ),

                    const SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(
                          14,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: temporaryCategory ??
                              '__all_cultures__',
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(
                              value: '__all_cultures__',
                              child: Text(
                                'All Cultural Categories',
                              ),
                            ),
                            for (final category in categories)
                              DropdownMenuItem(
                                value: category,
                                child: Text(
                                  category,
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            setBottomSheetState(
                                  () {
                                temporaryCategory =
                                value ==
                                    '__all_cultures__'
                                    ? null
                                    : value;
                              },
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // =========================================
                    // DIETARY NEEDS
                    // =========================================

                    const _FilterSectionTitle(
                      icon: Icons.restaurant_outlined,
                      title: 'Dietary Needs',
                    ),

                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final filter
                        in _DietaryFilter.values)
                          ChoiceChip(
                            avatar: Icon(
                              filter.icon,
                              size: 17,
                            ),
                            label: Text(
                              filter.label,
                            ),
                            selected:
                            temporaryDietary == filter,
                            onSelected: (_) {
                              setBottomSheetState(
                                    () {
                                  temporaryDietary = filter;
                                },
                              );
                            },
                          ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // =========================================
                    // HALAL NOTE
                    // =========================================

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .secondaryContainer
                            .withValues(
                          alpha: 0.35,
                        ),
                        borderRadius: BorderRadius.circular(
                          14,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: Theme.of(context)
                                .colorScheme
                                .secondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Halal status is shown for specific food locations because preparation and certification may differ between restaurants.',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // =========================================
                    // APPLY
                    // =========================================

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedState =
                                temporaryState;

                            _selectedCulturalCategory =
                                temporaryCategory;

                            _dietaryFilter =
                                temporaryDietary;
                          });

                          Navigator.pop(
                            bottomSheetContext,
                          );
                        },
                        icon: const Icon(
                          Icons.filter_alt_rounded,
                        ),
                        label: const Text(
                          'Apply Filters',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================
  // OPEN FOOD DETAILS
  // =========================================================

  void _openFoodDetails(
      TraditionalFood food,
      ) {
    context.push(
      CultureCommunityRoutes.foodDetail,
      extra: food,
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(
      traditionalFoodControllerProvider,
    );

    final allFoods = controller.foods;

    final foods = _filteredFoods(
      allFoods,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Traditional Food Guide',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: _buildBody(
          controller: controller,
          allFoods: allFoods,
          foods: foods,
        ),
      ),
    );
  }

  Widget _buildBody({
    required TraditionalFoodController controller,
    required List<TraditionalFood> allFoods,
    required List<TraditionalFood> foods,
  }) {
    // ========================================================
    // LOADING
    // ========================================================

    if (controller.isLoading &&
        controller.foods.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // ========================================================
    // ERROR
    // ========================================================

    if (controller.errorMessage != null &&
        controller.foods.isEmpty) {
      return ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(30),
        children: [
          const SizedBox(height: 120),

          const Icon(
            Icons.cloud_off_outlined,
            size: 52,
          ),

          const SizedBox(height: 12),

          Text(
            controller.errorMessage!,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          Center(
            child: FilledButton.icon(
              onPressed: controller.refresh,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text(
                'Try Again',
              ),
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (
          context,
          constraints,
          ) {
        final width = constraints.maxWidth;

        int columnCount;
        double cardHeight;

        if (width >= 1100) {
          columnCount = 4;
          cardHeight = 390;
        } else if (width >= 700) {
          columnCount = 3;
          cardHeight = 380;
        } else {
          // Mobile:
          // 2 columns but taller cards to prevent overflow.
          columnCount = 2;
          cardHeight = 350;
        }

        return ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            18,
            16,
            40,
          ),
          children: [
            // =================================================
            // INTRO
            // =================================================

            Text(
              'Taste Malaysia',
              style: GoogleFonts.montserrat(
                fontSize: 27,
                fontWeight: FontWeight.w700,
                color: Theme.of(context)
                    .colorScheme
                    .primary,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              'Explore traditional dishes, their cultural origins and the stories behind Malaysian cuisine.',
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.5,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 22),

            // =================================================
            // SEARCH + FILTER
            // =================================================

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction:
                    TextInputAction.search,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText:
                      'Search local delicacies...',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                      ),
                      suffixIcon:
                      _searchQuery.trim().isEmpty
                          ? null
                          : IconButton(
                        tooltip:
                        'Clear search',
                        onPressed: () {
                          _searchController
                              .clear();

                          setState(() {
                            _searchQuery = '';
                          });
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                        ),
                      ),
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius:
                        BorderRadius.circular(
                          16,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // =============================================
                // FILTER BUTTON
                // =============================================

                SizedBox(
                  width: 54,
                  height: 54,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: IconButton.filledTonal(
                          tooltip: 'Filters',
                          onPressed: () {
                            _showFilters(
                              allFoods,
                            );
                          },
                          icon: const Icon(
                            Icons.tune_rounded,
                          ),
                        ),
                      ),

                      if (_activeFilterCount > 0)
                        Positioned(
                          right: -2,
                          top: -4,
                          child: Container(
                            width: 21,
                            height: 21,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surface,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              '$_activeFilterCount',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimary,
                                fontSize: 10,
                                fontWeight:
                                FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // =================================================
            // ACTIVE FILTER CHIPS
            // =================================================

            if (_activeFilterCount > 0) ...[
              const SizedBox(height: 12),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (_selectedState != null) ...[
                      InputChip(
                        avatar: const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                        ),
                        label: Text(
                          _selectedState!,
                        ),
                        onDeleted: () {
                          setState(() {
                            _selectedState = null;
                          });
                        },
                      ),
                      const SizedBox(width: 7),
                    ],

                    if (_selectedCulturalCategory !=
                        null) ...[
                      InputChip(
                        avatar: const Icon(
                          Icons.groups_outlined,
                          size: 16,
                        ),
                        label: Text(
                          _selectedCulturalCategory!,
                        ),
                        onDeleted: () {
                          setState(() {
                            _selectedCulturalCategory =
                            null;
                          });
                        },
                      ),
                      const SizedBox(width: 7),
                    ],

                    if (_dietaryFilter !=
                        _DietaryFilter.all)
                      InputChip(
                        avatar: Icon(
                          _dietaryFilter.icon,
                          size: 16,
                        ),
                        label: Text(
                          _dietaryFilter.label,
                        ),
                        onDeleted: () {
                          setState(() {
                            _dietaryFilter =
                                _DietaryFilter.all;
                          });
                        },
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 30),

            // =================================================
            // DISCOVER HEADER
            // =================================================

            Row(
              crossAxisAlignment:
              CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Discover Delicacies',
                        style: GoogleFonts.montserrat(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context)
                              .colorScheme
                              .primary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Traditional Malaysian flavours and stories',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                Text(
                  '${foods.length} '
                      'result${foods.length == 1 ? '' : 's'}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                ),
              ],
            ),

            if (_hasActiveFilters) ...[
              const SizedBox(height: 5),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _clearAllFilters,
                  icon: const Icon(
                    Icons.filter_alt_off_outlined,
                    size: 16,
                  ),
                  label: const Text(
                    'Clear All',
                  ),
                ),
              ),
            ],

            const SizedBox(height: 10),

            // =================================================
            // NO RESULTS
            // =================================================

            if (foods.isEmpty)
              _NoFoodResult(
                hasFilters: _hasActiveFilters,
                onClear: _clearAllFilters,
              )

            // =================================================
            // FOOD GRID
            // =================================================

            else
              GridView.builder(
                shrinkWrap: true,
                physics:
                const NeverScrollableScrollPhysics(),
                itemCount: foods.length,

                // IMPORTANT:
                // mainAxisExtent gives each card enough
                // vertical space and prevents the bottom
                // overflow problem.
                gridDelegate:
                SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columnCount,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  mainAxisExtent: cardHeight,
                ),

                itemBuilder: (
                    context,
                    index,
                    ) {
                  final food = foods[index];

                  return _FoodGridCard(
                    food: food,
                    onTap: () {
                      _openFoodDetails(
                        food,
                      );
                    },
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

// ===========================================================
// FILTER SECTION TITLE
// ===========================================================

class _FilterSectionTitle extends StatelessWidget {
  const _FilterSectionTitle({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context)
              .colorScheme
              .primary,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================
// FOOD GRID CARD
// ===========================================================

class _FoodGridCard extends StatelessWidget {
  const _FoodGridCard({
    required this.food,
    required this.onTap,
  });

  final TraditionalFood food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      borderRadius:
      BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: colors.outlineVariant,
            ),
            borderRadius:
            BorderRadius.circular(
              18,
            ),
          ),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              // ===============================================
              // IMAGE
              // ===============================================

              AspectRatio(
                aspectRatio: 1.15,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _FoodImage(
                      food: food,
                    ),

                    // =========================================
                    // CULTURAL CATEGORY
                    // =========================================

                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        constraints:
                        const BoxConstraints(
                          maxWidth: 115,
                        ),
                        padding:
                        const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary
                              .withValues(
                            alpha: 0.92,
                          ),
                          borderRadius:
                          BorderRadius.circular(
                            999,
                          ),
                        ),
                        child: Text(
                          food.culturalCategory,
                          maxLines: 1,
                          overflow:
                          TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: colors.onPrimary,
                            fontSize: 8,
                            fontWeight:
                            FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    // =========================================
                    // DETAILS ARROW
                    // =========================================

                    Positioned(
                      right: 7,
                      top: 7,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white
                              .withValues(
                            alpha: 0.92,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ===============================================
              // INFORMATION
              // ===============================================

              Expanded(
                child: Padding(
                  padding:
                  const EdgeInsets.fromLTRB(
                    10,
                    10,
                    10,
                    9,
                  ),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      // =======================================
                      // FOOD NAME
                      // =======================================

                      Text(
                        food.name,
                        maxLines: 2,
                        overflow:
                        TextOverflow.ellipsis,
                        style:
                        GoogleFonts.montserrat(
                          fontSize: 14,
                          height: 1.15,
                          fontWeight:
                          FontWeight.w700,
                          color: colors.primary,
                        ),
                      ),

                      const SizedBox(height: 6),

                      // =======================================
                      // ORIGIN
                      // =======================================

                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: colors
                                .onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              food.region != null &&
                                  food.region!
                                      .trim()
                                      .isNotEmpty
                                  ? '${food.state} • ${food.region}'
                                  : food.state,
                              maxLines: 1,
                              overflow:
                              TextOverflow.ellipsis,
                              style:
                              GoogleFonts.inter(
                                fontSize: 9,
                                color: colors
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 7),

                      // =======================================
                      // DESCRIPTION
                      // =======================================

                      Expanded(
                        child: Text(
                          food.description,
                          maxLines: 3,
                          overflow:
                          TextOverflow.ellipsis,
                          style:
                          GoogleFonts.inter(
                            fontSize: 10,
                            height: 1.3,
                            color: colors
                                .onSurfaceVariant,
                          ),
                        ),
                      ),

                      const SizedBox(height: 7),

                      // =======================================
                      // TAGS
                      // =======================================

                      _FoodCardTags(
                        food: food,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================
// FOOD CARD TAGS
// ===========================================================

class _FoodCardTags extends StatelessWidget {
  const _FoodCardTags({
    required this.food,
  });

  final TraditionalFood food;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    final tags = <String>[];

    // Add first dietary tag.
    if (food.dietaryTags.isNotEmpty) {
      tags.add(
        food.dietaryTags.first,
      );
    }

    // Show allergen information if available.
    if (food.allergens.isNotEmpty ||
        (food.allergyNotes != null &&
            food.allergyNotes!.trim().isNotEmpty)) {
      tags.add(
        'Allergen Info',
      );
    }

    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        for (final tag in tags.take(2))
          Padding(
            padding: const EdgeInsets.only(
              bottom: 4,
            ),
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: double.infinity,
              ),
              padding:
              const EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius:
                BorderRadius.circular(
                  999,
                ),
              ),
              child: Text(
                _displayTag(tag),
                maxLines: 1,
                overflow:
                TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 8,
                  fontWeight:
                  FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ===========================================================
// FOOD IMAGE
// ===========================================================

class _FoodImage extends StatelessWidget {
  const _FoodImage({
    required this.food,
  });

  final TraditionalFood food;

  @override
  Widget build(BuildContext context) {
    final url = food.imageUrl?.trim();

    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) {
          return _fallback(
            context,
          );
        },
      );
    }

    return _fallback(
      context,
    );
  }

  Widget _fallback(
      BuildContext context,
      ) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.secondaryContainer,
            colors.surfaceContainerHighest,
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.restaurant_rounded,
        size: 52,
        color:
        colors.onSecondaryContainer,
      ),
    );
  }
}

// ===========================================================
// NO FOOD RESULT
// ===========================================================

class _NoFoodResult extends StatelessWidget {
  const _NoFoodResult({
    required this.hasFilters,
    required this.onClear,
  });

  final bool hasFilters;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 50,
      ),
      child: Column(
        children: [
          Icon(
            Icons.no_food_outlined,
            size: 52,
            color: Theme.of(context)
                .colorScheme
                .outline,
          ),

          const SizedBox(height: 12),

          Text(
            hasFilters
                ? 'No traditional food matches your filters.'
                : 'No traditional food is available.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontWeight:
              FontWeight.w600,
            ),
          ),

          if (hasFilters) ...[
            const SizedBox(height: 12),

            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(
                Icons.filter_alt_off_outlined,
              ),
              label: const Text(
                'Clear Filters',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ===========================================================
// DISPLAY TAG
// ===========================================================

String _displayTag(
    String value,
    ) {
  if (value.trim().isEmpty) {
    return value;
  }

  final normalized = value
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .trim();

  return normalized
      .split(' ')
      .where(
        (word) => word.isNotEmpty,
  )
      .map(
        (word) =>
    word[0].toUpperCase() +
        word.substring(1),
  )
      .join(' ');
}