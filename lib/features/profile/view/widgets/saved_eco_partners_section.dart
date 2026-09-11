import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../travel_assistant/model/saved_eco_partners_store.dart';
import '../../../travel_assistant/view/widgets/saved_eco_partner_tile.dart';

class SavedEcoPartnersSection extends StatefulWidget {
  const SavedEcoPartnersSection({super.key, this.store});

  final SavedEcoPartnersStore? store;

  @override
  State<SavedEcoPartnersSection> createState() =>
      _SavedEcoPartnersSectionState();
}

class _SavedEcoPartnersSectionState extends State<SavedEcoPartnersSection> {
  SavedEcoPartnersStore get _store =>
      widget.store ?? SavedEcoPartnersStore.instance;

  @override
  void initState() {
    super.initState();
    _store.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _store,
    builder: (context, _) {
      final store = _store;
      final title = 'Eco Partners (${store.saved.length})';
      final colors = AppColors.of(context);

      if (store.isLoading && store.saved.isEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title: title),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        );
      }
      if (store.error != null && store.saved.isEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title: title),
            const SizedBox(height: 6),
            Text(
              store.error!,
              style: AppTypography.bodySm.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: store.refresh,
              child: const Text('Retry'),
            ),
          ],
        );
      }
      if (store.saved.isEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title: title),
            const SizedBox(height: 6),
            Text(
              'No saved Eco Partners yet — save one from Eco Partner recommendations.',
              style: AppTypography.bodySm.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        );
      }

      return Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          maintainState: true,
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: _SectionTitle(title: title),
          children: [
            for (final saved in store.saved)
              SavedEcoPartnerTile(
                saved: saved,
                onRemove: () => store.remove(saved.id),
              ),
          ],
        ),
      );
    },
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: AppTypography.bodySm.copyWith(
      color: AppColors.of(context).onSurfaceVariant,
      fontWeight: FontWeight.w700,
    ),
  );
}
