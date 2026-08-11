import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../config/theme.dart';
import '../../../gamification_journal/model/badge_model.dart';
import '../../../../shared/widgets/badge_card.dart';

/// A single featured photo plus the destination it was taken at — the
/// share card capability doesn't just want a media URL, it wants to say
/// *where* each photo is from, so this pairs the two instead of reusing
/// the plain [JournalMediaModel] (which has no destination reference of
/// its own).
class SharePhoto {
  const SharePhoto({required this.url, required this.destinationName});

  final String url;
  final String destinationName;
}

/// Opens a preview of the exportable share card and, on confirm, renders
/// it off-screen, captures it as a PNG, and hands it to the device's share
/// sheet. The card is a deliberately stripped-down summary — a few photos,
/// a handful of stats, top badges — meant to travel outside the app,
/// unlike the full (and much busier) in-app Profile page. Photos only —
/// videos don't make sense as a still image capture, so callers should
/// never pass one in here.
Future<void> showProfileShareSheet(
  BuildContext context, {
  required String travellerName,
  required int checkIns,
  required int badgesEarned,
  required int statesExplored,
  required int totalMalaysianRegions,
  required double economicImpactTotalRM,
  required List<SharePhoto> photos,
  required List<BadgeModel> topBadges,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => _ProfileShareSheet(
      travellerName: travellerName,
      checkIns: checkIns,
      badgesEarned: badgesEarned,
      statesExplored: statesExplored,
      totalMalaysianRegions: totalMalaysianRegions,
      economicImpactTotalRM: economicImpactTotalRM,
      photos: photos,
      topBadges: topBadges,
    ),
  );
}

class _ProfileShareSheet extends StatefulWidget {
  const _ProfileShareSheet({
    required this.travellerName,
    required this.checkIns,
    required this.badgesEarned,
    required this.statesExplored,
    required this.totalMalaysianRegions,
    required this.economicImpactTotalRM,
    required this.photos,
    required this.topBadges,
  });

  final String travellerName;
  final int checkIns;
  final int badgesEarned;
  final int statesExplored;
  final int totalMalaysianRegions;
  final double economicImpactTotalRM;
  final List<SharePhoto> photos;
  final List<BadgeModel> topBadges;

  @override
  State<_ProfileShareSheet> createState() => _ProfileShareSheetState();
}

class _ProfileShareSheetState extends State<_ProfileShareSheet> {
  final _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      // Card was just built this frame — wait one more so any network
      // images in it have had a chance to decode before capture.
      await Future.delayed(const Duration(milliseconds: 50));

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      // Unique name per share (not a fixed filename) so the OS never has a
      // stale cached copy — some platforms key file metadata off the path
      // and can otherwise treat a re-share as "nothing new to attach".
      final file = File('${tempDir.path}/hidden_gems_trail_${DateTime.now().millisecondsSinceEpoch}.png');
      // flush: true forces the bytes fully to disk before the OS share
      // sheet tries to read the file — without it, a share triggered right
      // after the write can race a buffered file and see 0 bytes.
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png', name: 'hidden_gems_trail.png')],
        text: "${widget.travellerName}'s hidden gem trail on Hidden Gems of Malaysia",
      );
    } catch (e, stackTrace) {
      debugPrint('ProfileShareSheet: share failed: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not share your trail. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Share your trail', style: AppTypography.headlineSm),
              const SizedBox(height: 4),
              Text(
                'A quick preview of what gets shared — just the highlights, not your full profile.',
                style: AppTypography.bodySm.copyWith(color: AppColors.of(context).onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Center(
                child: RepaintBoundary(
                  key: _cardKey,
                  child: _ProfileShareCard(
                    travellerName: widget.travellerName,
                    checkIns: widget.checkIns,
                    badgesEarned: widget.badgesEarned,
                    statesExplored: widget.statesExplored,
                    totalMalaysianRegions: widget.totalMalaysianRegions,
                    economicImpactTotalRM: widget.economicImpactTotalRM,
                    photos: widget.photos,
                    topBadges: widget.topBadges,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _sharing ? null : _share,
                  icon: _sharing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.share, size: 18),
                  label: Text(_sharing ? 'Preparing…' : 'Share'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The card that actually gets captured and shared — square-ish, dense
/// with visuals, no app chrome. Kept deliberately separate from the
/// in-app Profile layout so tweaking one never breaks the other.
class _ProfileShareCard extends StatelessWidget {
  const _ProfileShareCard({
    required this.travellerName,
    required this.checkIns,
    required this.badgesEarned,
    required this.statesExplored,
    required this.totalMalaysianRegions,
    required this.economicImpactTotalRM,
    required this.photos,
    required this.topBadges,
  });

  final String travellerName;
  final int checkIns;
  final int badgesEarned;
  final int statesExplored;
  final int totalMalaysianRegions;
  final double economicImpactTotalRM;
  final List<SharePhoto> photos;
  final List<BadgeModel> topBadges;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final displayPhotos = photos.take(3).toList();

    return Container(
      width: 320,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: colors.primaryContainer,
                child: Icon(Icons.person, color: colors.onPrimaryContainer),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$travellerName's hidden gem trail",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text('Hidden Gems Malaysia', style: AppTypography.labelSm),
                  ],
                ),
              ),
            ],
          ),
          if (displayPhotos.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                for (var i = 0; i < displayPhotos.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(child: _SharePhotoTile(photo: displayPhotos[i])),
                ],
              ],
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _ShareStat(icon: Icons.map_outlined, label: '$checkIns gems'),
              _ShareStat(icon: Icons.emoji_events_outlined, label: '$badgesEarned badges'),
              _ShareStat(icon: Icons.public, label: '$statesExplored/$totalMalaysianRegions states'),
              if (economicImpactTotalRM > 0)
                _ShareStat(
                  icon: Icons.volunteer_activism_outlined,
                  label: 'RM ${economicImpactTotalRM.toStringAsFixed(0)} local impact',
                ),
            ],
          ),
          if (topBadges.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final badge in topBadges) _BadgeChip(badge: badge),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Container(height: 1, color: colors.outlineVariant),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.explore_outlined, size: 13, color: colors.onSurfaceVariant),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Discover more hidden gems on the Hidden Gems Malaysia app',
                  style: AppTypography.labelSm.copyWith(fontSize: 10),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A photo with its destination name captioned across the bottom (a
/// gradient scrim behind the text keeps it legible over any photo).
class _SharePhotoTile extends StatelessWidget {
  const _SharePhotoTile({required this.photo});

  final SharePhoto photo;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              photo.url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(color: colors.surfaceContainerHigh),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 14, 6, 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withValues(alpha: 0), Colors.black.withValues(alpha: 0.75)],
                  ),
                ),
                child: Text(
                  photo.destinationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A named badge, not just its icon — an icon alone means nothing to
/// someone outside the app looking at a shared post.
class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.badge});

  final BadgeModel badge;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconForBadge(badge), size: 12, color: colors.onSecondaryContainer),
          const SizedBox(width: 4),
          Text(
            badge.name,
            style: AppTypography.labelSm.copyWith(fontSize: 10, color: colors.onSecondaryContainer),
          ),
        ],
      ),
    );
  }
}

class _ShareStat extends StatelessWidget {
  const _ShareStat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: colors.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(label, style: AppTypography.labelSm),
      ],
    );
  }
}
