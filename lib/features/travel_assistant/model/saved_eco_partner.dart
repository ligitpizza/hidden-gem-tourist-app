import 'eco_partner.dart';

class SavedEcoPartner {
  const SavedEcoPartner({
    required this.id,
    required this.partner,
    required this.savedAt,
  });

  final String id;
  final EcoPartner partner;
  final DateTime savedAt;
}
