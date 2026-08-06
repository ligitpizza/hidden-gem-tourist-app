import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../features/gamification_journal/model/destination_model.dart';
import '../../features/gamification_journal/model/journal_entry_model.dart';
import '../../features/gamification_journal/model/journal_media_model.dart';

class JournalCard extends StatelessWidget {
  const JournalCard({
    super.key,
    required this.entry,
    required this.destination,
    required this.onTap,
    required this.onDelete,
  });

  final JournalEntryModel entry;
  final DestinationModel? destination;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  String _formatDate(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    final hasNotes = entry.notes.trim().isNotEmpty;
    final totalSpending = entry.totalSpendingRM;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(entry.createdAt).toUpperCase(),
                          style: AppTypography.labelSm.copyWith(fontSize: 10.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          destination?.name ?? 'Unknown destination',
                          style: AppTypography.headlineSm.copyWith(fontSize: 17, color: AppColors.primaryContainer),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 19, color: AppColors.onSurfaceVariant),
                    onPressed: onTap,
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 19, color: AppColors.error),
                    onPressed: onDelete,
                    tooltip: 'Delete',
                  ),
                ],
              ),
              if (entry.media.isNotEmpty) ...[
                const SizedBox(height: 4),
                _MediaPreview(media: entry.media),
              ],
              if (hasNotes) ...[
                const SizedBox(height: 12),
                Text(
                  entry.notes,
                  maxLines: entry.media.isEmpty ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant, height: 1.5),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (totalSpending > 0)
                    _Pill(
                      icon: Icons.volunteer_activism,
                      label: 'Local Impact: RM ${totalSpending.toStringAsFixed(0)}',
                      background: AppColors.primaryContainer,
                      foreground: AppColors.onPrimary,
                    )
                  else
                    const _Pill(
                      icon: Icons.visibility_outlined,
                      label: 'Field Note',
                      background: AppColors.tertiaryContainer,
                      foreground: AppColors.onTertiaryContainer,
                    ),
                  if (destination != null)
                    _Pill(
                      icon: Icons.place_outlined,
                      label: destination!.category,
                      background: AppColors.secondaryContainer,
                      foreground: AppColors.onSecondaryContainer,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.background, required this.foreground});

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 6),
          Text(label, style: AppTypography.labelSm.copyWith(color: foreground, fontSize: 11)),
        ],
      ),
    );
  }
}

/// Single photo/video → one full-width tile. Multiple → equal-width tiles
/// side by side (all the same size regardless of photo vs. video) with a
/// "+N" overlay on the last visible tile when there's more than fit.
class _MediaPreview extends StatelessWidget {
  const _MediaPreview({required this.media});

  final List<JournalMediaModel> media;

  Widget _tile(JournalMediaModel item, {int? overlayCount}) {
    final isVideo = item.type == JournalMediaType.video;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          _MediaNetworkImage(url: item.url, isVideo: isVideo),
          if (isVideo)
            const Icon(Icons.play_circle_fill, color: Colors.white70, size: 26),
          if (overlayCount != null)
            Container(
              color: Colors.black.withValues(alpha: 0.45),
              alignment: Alignment.center,
              child: Text(
                '+$overlayCount',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (media.length == 1) {
      return AspectRatio(aspectRatio: 16 / 9, child: _tile(media.first));
    }

    final visible = media.take(3).toList();
    final extra = media.length - visible.length;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Row(
        children: [
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: _tile(
                visible[i],
                overlayCount: (i == visible.length - 1 && extra > 0) ? extra : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Renders the media's network image with a themed fallback (loading spinner,
/// or the tonal gradient block) if it hasn't loaded or the request fails.
class _MediaNetworkImage extends StatelessWidget {
  const _MediaNetworkImage({required this.url, required this.isVideo});

  final String url;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _fallback(loading: true);
      },
      errorBuilder: (context, error, stackTrace) => _fallback(loading: false),
    );
  }

  Widget _fallback({required bool loading}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isVideo
              ? const [Color(0xFF3A3222), Color(0xFF14110B)]
              : const [Color(0xFF2C4A3B), Color(0xFF0D1B15)],
        ),
      ),
      child: loading
          ? const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
              ),
            )
          : null,
    );
  }
}
