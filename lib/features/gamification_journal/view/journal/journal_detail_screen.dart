import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../config/theme.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/journal_media_carousel.dart';
import '../../controller/journal_controller.dart';
import '../../model/destination_model.dart';
import '../../model/journal_entry_model.dart';
import '../../model/journal_media_model.dart';

class JournalDetailScreen extends StatefulWidget {
  const JournalDetailScreen({super.key, required this.entry, this.destination});

  final JournalEntryModel entry;
  final DestinationModel? destination;

  @override
  State<JournalDetailScreen> createState() => _JournalDetailScreenState();
}

class _CategoryField {
  _CategoryField(this.option, this.icon, double? initial)
    : controller = TextEditingController(text: initial == null || initial == 0 ? '' : initial.toStringAsFixed(0));

  final LocalSupportOption option;
  final IconData icon;
  final TextEditingController controller;
}

class _JournalDetailScreenState extends State<JournalDetailScreen> {
  late final TextEditingController _notesController;
  late List<_CategoryField> _categoryFields;
  late List<JournalMediaModel> _media;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.entry.notes);
    _categoryFields = [
      _CategoryField(
        LocalSupportOption.foodCafe,
        Icons.restaurant_outlined,
        widget.entry.spendingByCategory[LocalSupportOption.foodCafe],
      ),
      _CategoryField(
        LocalSupportOption.souvenirsHandicrafts,
        Icons.card_giftcard_outlined,
        widget.entry.spendingByCategory[LocalSupportOption.souvenirsHandicrafts],
      ),
      _CategoryField(
        LocalSupportOption.localGuideTransport,
        Icons.directions_bus_outlined,
        widget.entry.spendingByCategory[LocalSupportOption.localGuideTransport],
      ),
    ];
    _media = widget.entry.media;
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (final field in _categoryFields) {
      field.controller.dispose();
    }
    super.dispose();
  }

  void _syncMediaFromController() {
    final journalController = context.read<JournalController>();
    setState(() {
      _media = journalController.entries.firstWhere((e) => e.id == widget.entry.id).media;
    });
  }

  Future<void> _handleAddMedia(JournalMediaType type) async {
    final journalController = context.read<JournalController>();
    // TODO(phase1): swap for image_picker (photo) / a video picker once
    // device media access is wired in — this simulates picking a local file.
    await journalController.addMedia(
      widget.entry.id,
      localFilePath: type == JournalMediaType.video ? 'mock/local_video.mp4' : 'mock/local_photo.jpg',
      type: type,
    );
    if (!mounted) return;
    _syncMediaFromController();
  }

  Future<void> _handleRemoveMedia(String mediaId) async {
    await context.read<JournalController>().removeMedia(widget.entry.id, mediaId);
    if (!mounted) return;
    _syncMediaFromController();
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);

    final spendingByCategory = <LocalSupportOption, double>{};
    for (final field in _categoryFields) {
      final text = field.controller.text.trim();
      if (text.isEmpty) continue;
      final amount = double.tryParse(text);
      if (amount != null && amount > 0) {
        spendingByCategory[field.option] = amount;
      }
    }

    await context.read<JournalController>().saveDetails(
      widget.entry.id,
      notes: _notesController.text,
      spendingByCategory: spendingByCategory,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Journal entry saved')));
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete journal entry?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await context.read<JournalController>().deleteEntry(widget.entry.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader.pushed(title: 'Journal entry'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.destination?.name ?? 'Unknown destination',
              style: AppTypography.headlineLgMobile.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.entry.createdAt.day}/${widget.entry.createdAt.month}/${widget.entry.createdAt.year}',
              style: AppTypography.bodySm,
            ),
            const SizedBox(height: 16),

            JournalMediaCarousel(
              media: _media,
              onAddPhoto: () => _handleAddMedia(JournalMediaType.photo),
              onAddVideo: () => _handleAddMedia(JournalMediaType.video),
              onRemove: _handleRemoveMedia,
            ),
            const SizedBox(height: 20),

            Text('Notes', style: AppTypography.headlineSm.copyWith(fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 5,
              decoration: const InputDecoration(hintText: 'What made this place worth the trip?'),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Local spending, by category', style: AppTypography.headlineSm.copyWith(fontSize: 14)),
                Text('Optional', style: AppTypography.bodySm),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "Leave a category blank if you didn't spend there — no spending logged is fine too",
              style: AppTypography.bodySm,
            ),
            const SizedBox(height: 10),
            for (final field in _categoryFields)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CategorySpendRow(field: field),
              ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.onPrimary),
                      )
                    : const Text('Save entry'),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                label: const Text('Delete entry', style: TextStyle(color: AppColors.error)),
                onPressed: _handleDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySpendRow extends StatelessWidget {
  const _CategorySpendRow({required this.field});

  final _CategoryField field;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outlineVariant, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primaryContainerTint,
              borderRadius: BorderRadius.circular(AppRadius.base),
            ),
            child: Icon(field.icon, size: 15, color: AppColors.primaryContainer),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(field.option.label, style: AppTypography.bodySm.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            width: 74,
            child: TextField(
              controller: field.controller,
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: AppTypography.bodySm.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                isDense: true,
                prefixText: 'RM ',
                hintText: '—',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
