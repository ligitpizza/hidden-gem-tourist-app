import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../features/gamification_journal/model/journal_media_model.dart';
import 'journal_video_player_screen.dart';

/// Horizontally-scrolling photo/video carousel for a journal entry. When
/// there's already at least one item, a trailing "Manage" tile opens a
/// sheet to add more or remove existing media — otherwise the only tile is
/// a plain "Add photos or a video" prompt.
class JournalMediaCarousel extends StatefulWidget {
  const JournalMediaCarousel({
    super.key,
    required this.media,
    required this.onAddPhoto,
    required this.onAddVideo,
    required this.onRemove,
    this.isUploading = false,
  });

  final List<JournalMediaModel> media;
  final VoidCallback onAddPhoto;
  final VoidCallback onAddVideo;
  final ValueChanged<String> onRemove;

  /// True while a picked photo/video is being uploaded — disables the add
  /// buttons (so a Tourist can't fire off a pile of taps while waiting)
  /// and shows a progress indicator so the wait itself is visible.
  final bool isUploading;

  @override
  State<JournalMediaCarousel> createState() => _JournalMediaCarouselState();
}

class _JournalMediaCarouselState extends State<JournalMediaCarousel> {
  late final PageController _pageController;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.8);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _manage(BuildContext context) {
    if (widget.isUploading) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Manage photos & videos', style: AppTypography.headlineSm),
                const SizedBox(height: 14),
                for (final item in widget.media)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.of(context).surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Icon(
                            item.type == JournalMediaType.video
                                ? Icons.videocam_outlined
                                : Icons.image_outlined,
                            color: AppColors.of(context).onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.type == JournalMediaType.video ? 'Video' : 'Photo',
                            style: AppTypography.bodyMd,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: AppColors.of(context).error),
                          onPressed: () {
                            widget.onRemove(item.id);
                            Navigator.of(sheetContext).pop();
                          },
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add_a_photo_outlined, size: 17),
                        label: const Text('Add photo'),
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          widget.onAddPhoto();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.videocam_outlined, size: 17),
                        label: const Text('Add video'),
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          widget.onAddVideo();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMedia = widget.media.isNotEmpty;

    if (!hasMedia) {
      return Column(
        children: [
          _AddTile(
            onAddPhoto: widget.onAddPhoto,
            onAddVideo: widget.onAddVideo,
            fullWidth: true,
            disabled: widget.isUploading,
          ),
          if (widget.isUploading) ...[
            const SizedBox(height: 10),
            const _UploadProgressRow(),
          ],
        ],
      );
    }

    final pageCount = widget.media.length + 1; // + trailing manage tile

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _pageController,
            itemCount: pageCount,
            onPageChanged: (index) => setState(() => _page = index),
            itemBuilder: (context, index) {
              if (index == widget.media.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _ManageTile(onTap: () => _manage(context), disabled: widget.isUploading),
                );
              }
              final item = widget.media[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _MediaTile(item: item),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.media.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: EdgeInsets.symmetric(horizontal: 2.5),
                width: i == _page ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page ? AppColors.of(context).primary : AppColors.of(context).outlineVariant,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
          ],
        ),
        if (widget.isUploading) ...[
          const SizedBox(height: 10),
          const _UploadProgressRow(),
        ],
      ],
    );
  }
}

class _UploadProgressRow extends StatelessWidget {
  const _UploadProgressRow();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              minHeight: 4,
              backgroundColor: colors.outlineVariant.withValues(alpha: 0.4),
              color: colors.primary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('Uploading…', style: AppTypography.labelSm),
      ],
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({required this.item});

  final JournalMediaModel item;

  void _openVideo(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => JournalVideoPlayerScreen(url: item.url)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = item.type == JournalMediaType.video;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: GestureDetector(
        onTap: isVideo ? () => _openVideo(context) : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video files can't be decoded as images — a video's tile is
            // always the dark placeholder with a play button; only photos
            // actually load through Image.network.
            if (isVideo)
              _fallback(isVideo, loading: false)
            else
              Image.network(
                item.url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return _fallback(isVideo, loading: true);
                },
                errorBuilder: (context, error, stackTrace) => _fallback(isVideo, loading: false),
              ),
            Positioned(
              left: 10,
              top: 10,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  isVideo ? 'VIDEO' : 'PHOTO',
                  style: AppTypography.labelSm.copyWith(color: Colors.white, fontSize: 9.5),
                ),
              ),
            ),
            if (isVideo)
              Center(
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.play_arrow, color: AppColors.of(context).primary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fallback(bool isVideo, {required bool loading}) {
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

class _ManageTile extends StatelessWidget {
  const _ManageTile({required this.onTap, this.disabled = false});

  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: colors.outlineVariant, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.tune, color: colors.onSurfaceVariant, size: 24),
              const SizedBox(height: 6),
              Text('Manage', style: AppTypography.labelSm),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two explicit, equally-discoverable buttons — a plain tap used to only
/// add a photo, with video reachable solely via a long-press nobody would
/// find on their own.
class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.onAddPhoto,
    required this.onAddVideo,
    this.fullWidth = false,
    this.disabled = false,
  });

  final VoidCallback onAddPhoto;
  final VoidCallback onAddVideo;
  final bool fullWidth;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: colors.outlineVariant, width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: _AddTileButton(
                icon: Icons.add_photo_alternate_outlined,
                label: 'Add photo',
                onTap: onAddPhoto,
                disabled: disabled,
              ),
            ),
            VerticalDivider(width: 1, thickness: 1.5, color: colors.outlineVariant),
            Expanded(
              child: _AddTileButton(
                icon: Icons.videocam_outlined,
                label: 'Add video',
                onTap: onAddVideo,
                disabled: disabled,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddTileButton extends StatelessWidget {
  const _AddTileButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.disabled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: InkWell(
        onTap: disabled ? null : onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.of(context).onSurfaceVariant, size: 26),
            const SizedBox(height: 6),
            Text(label, style: AppTypography.labelSm),
          ],
        ),
      ),
    );
  }
}
