import 'package:flutter/material.dart';

import '../../model/saved_eco_partner.dart';
import '../../model/saved_eco_partners_store.dart';
import '../eco_partner_detail_screen.dart';

class SavedEcoPartnerTile extends StatelessWidget {
  const SavedEcoPartnerTile({super.key, required this.saved});

  final SavedEcoPartner saved;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.eco_outlined)),
        title: Text(saved.partner.name),
        subtitle: Text(
          saved.partner.address.isEmpty
              ? saved.partner.subtype
              : '${saved.partner.subtype} · ${saved.partner.address}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EcoPartnerDetailScreen(
              partner: saved.partner,
              destinationLabel: saved.partner.address,
            ),
          ),
        ),
        trailing: IconButton(
          tooltip: 'Remove saved Eco Partner',
          onPressed: () => SavedEcoPartnersStore.instance.remove(saved.id),
          icon: const Icon(Icons.bookmark_remove_outlined),
        ),
      ),
    ),
  );
}
