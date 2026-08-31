import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../config/theme.dart';
import '../../../../shared/widgets/badge_card.dart';
import '../../model/badge_model.dart';

/// Opens a preview of a single unlocked badge and, on confirm, renders it
/// off-screen, captures it as a PNG, and hands it to the device's share
/// sheet. Same capture-and-share mechanism as
/// profile_share_sheet.dart's trail card — kept as a separate, single-badge
/// card here since "share this one achievement" and "share my whole trail"
/// are different moments for the Tourist.
Future<void> showBadgeShareSheet(
  BuildContext context, {
  required BadgeModel badge,
  required DateTime earnedAt,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => _BadgeShareSheet(badge: badge, earnedAt: earnedAt),
  );
}

class _BadgeShareSheet extends StatefulWidget {
  const _BadgeShareSheet({required this.badge, required this.earnedAt});

  final BadgeModel badge;
  final DateTime earnedAt;

  @override
  State<_BadgeShareSheet> createState() => _BadgeShareSheetState();
}

class _BadgeShareSheetState extends State<_BadgeShareSheet> {
  final _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      // Card was just built this frame — wait one more so it's fully
      // painted before capture.
      await Future.delayed(const Duration(milliseconds: 50));

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      // Unique name per share (not a fixed filename) so the OS never has a
      // stale cached copy — some platforms key file metadata off the path
      // and can otherwise treat a re-share as "nothing new to attach".
      final file = File('${tempDir.path}/hidden_gems_badge_${DateTime.now().millisecondsSinceEpoch}.png');
      // flush: true forces the bytes fully to disk before the OS share
      // sheet tries to read the file — without it, a share triggered right
      // after the write can race a buffered file and see 0 bytes.
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png', name: 'hidden_gems_badge.png')],
        text: 'I just earned the "${widget.badge.name}" badge on Hidden Gems Malaysia!',
      );
    } catch (e, stackTrace) {
      debugPrint('BadgeShareSheet: share failed: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not share this badge. Please try again.')),
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
              Text('Share this achievement', style: AppTypography.headlineSm),
              const SizedBox(height: 4),
              Text(
                'A quick preview of what gets shared.',
                style: AppTypography.bodySm.copyWith(color: AppColors.of(context).onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Center(
                child: RepaintBoundary(
                  key: _cardKey,
                  child: _BadgeShareCard(badge: widget.badge, earnedAt: widget.earnedAt),
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

/// The card that actually gets captured and shared — kept deliberately
/// separate from the in-app badge detail sheet so tweaking one never
/// breaks the other.
class _BadgeShareCard extends StatelessWidget {
  const _BadgeShareCard({required this.badge, required this.earnedAt});

  final BadgeModel badge;
  final DateTime earnedAt;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      width: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colors.secondaryContainer, shape: BoxShape.circle),
            child: Icon(iconForBadge(badge), size: 36, color: colors.onSecondaryContainer),
          ),
          const SizedBox(height: 14),
          Text(badge.name, style: AppTypography.headlineSm, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            'ACHIEVEMENT UNLOCKED',
            style: AppTypography.labelMd.copyWith(
              color: colors.secondary,
              letterSpacing: 0.08 * 14,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            badge.description,
            textAlign: TextAlign.center,
            style: AppTypography.bodySm.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Text(
            'Earned on ${earnedAt.day}/${earnedAt.month}/${earnedAt.year}',
            style: AppTypography.bodySm,
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: colors.outlineVariant),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.explore_outlined, size: 13, color: colors.onSurfaceVariant),
              const SizedBox(width: 5),
              Flexible(
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
