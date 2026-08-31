import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controller/hidden_gem_search_controller.dart';
import 'hidden_gem_recommendation_routes.dart';
import 'widgets/hidden_gem_list_tile.dart';

/// "Search For Gem" (UC diagram) — reached by tapping the discovery feed's
/// search bar. A real query over Hidden Gem Score-ranked data, not the
/// static label it used to be.
class HiddenGemSearchScreen extends ConsumerStatefulWidget {
  const HiddenGemSearchScreen({super.key});

  @override
  ConsumerState<HiddenGemSearchScreen> createState() => _HiddenGemSearchScreenState();
}

class _HiddenGemSearchScreenState extends ConsumerState<HiddenGemSearchScreen> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(hiddenGemSearchControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _textController,
          focusNode: _focusNode,
          decoration: const InputDecoration(
            hintText: 'Search for a hidden gem…',
            border: InputBorder.none,
          ),
          onChanged: (value) => ref.read(hiddenGemSearchControllerProvider).search(value),
        ),
        actions: [
          if (_textController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _textController.clear();
                ref.read(hiddenGemSearchControllerProvider).clearQuery();
                setState(() {});
              },
            ),
        ],
      ),
      body: _buildBody(context, controller, colorScheme),
    );
  }

  Widget _buildBody(BuildContext context, HiddenGemSearchController controller, ColorScheme colorScheme) {
    if (controller.query.trim().isEmpty) {
      if (controller.recentSearches.isEmpty) {
        return Center(
          child: Text(
            'Search hidden gems by name.',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        );
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent searches', style: Theme.of(context).textTheme.titleSmall),
              TextButton(
                onPressed: () => ref.read(hiddenGemSearchControllerProvider).clearRecentSearches(),
                child: const Text('Clear'),
              ),
            ],
          ),
          for (final term in controller.recentSearches)
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(term),
              onTap: () {
                _textController.text = term;
                ref.read(hiddenGemSearchControllerProvider).search(term);
              },
            ),
        ],
      );
    }

    if (controller.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.results.isEmpty) {
      return Center(
        child: Text(
          'No hidden gems match "${controller.query}".',
          textAlign: TextAlign.center,
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: controller.results.length,
      itemBuilder: (context, index) {
        final item = controller.results[index];
        return HiddenGemListTile(
          item: item,
          onTap: () {
            ref.read(hiddenGemSearchControllerProvider).logResultTap(item);
            context.push(HiddenGemRecommendationRoutes.scoreDetail, extra: item);
          },
        );
      },
    );
  }
}
