import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../config/theme.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../controller/friend_controller.dart';
import '../../model/friend_model.dart';
import 'friend_profile_preview_screen.dart';

class FriendSearchScreen extends StatefulWidget {
  const FriendSearchScreen({super.key});

  @override
  State<FriendSearchScreen> createState() => _FriendSearchScreenState();
}

class _FriendSearchScreenState extends State<FriendSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    context.read<FriendController>().clearSearch();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      context.read<FriendController>().clearSearch();
      return;
    }
    // Waits for a pause in typing before searching — avoids firing a query
    // on every keystroke.
    _debounce = Timer(const Duration(milliseconds: 350), () {
      context.read<FriendController>().searchByName(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final friendController = context.watch<FriendController>();
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppHeader.pushed(title: 'Add friend'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                hintText: 'Search by name…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: friendController.isSearching
                ? const Center(child: CircularProgressIndicator())
                : friendController.searchResults.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _controller.text.trim().isEmpty
                              ? 'Search for a fellow Tourist by their display name.'
                              : 'No one found with that name.',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySm.copyWith(color: colors.onSurfaceVariant),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: friendController.searchResults.length,
                        itemBuilder: (context, index) =>
                            _SearchResultTile(profile: friendController.searchResults[index]),
                      ),
          ),
        ],
      ),
    );
  }
}

/// Tapping the row (rather than an inline Add button) opens the full
/// profile preview — that's where Add Friend / Accept / Remove actually
/// live now, alongside the stats a Tourist would want to see before
/// deciding to add someone.
class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.profile});

  final ProfileModel profile;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final friendController = context.watch<FriendController>();
    final relationship = friendController.relationshipWith(profile.id);
    final name = profile.fullName.isEmpty ? 'Someone' : profile.fullName;

    String? statusLabel;
    if (relationship != null) {
      statusLabel = relationship.status == FriendshipStatus.accepted ? 'Friends' : 'Pending';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => FriendProfilePreviewScreen(profile: profile)),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: colors.primaryContainerTint,
                child: Text(
                  name[0].toUpperCase(),
                  style: AppTypography.bodySm.copyWith(
                    color: colors.primaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(name, style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
              ),
              if (statusLabel != null) ...[
                Text(statusLabel, style: AppTypography.labelSm.copyWith(color: colors.onSurfaceVariant)),
                const SizedBox(width: 4),
              ],
              Icon(Icons.chevron_right, size: 18, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
