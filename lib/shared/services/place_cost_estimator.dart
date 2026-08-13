import '../models/destination.dart';

/// Rough, category-based MYR cost per visit — a stand-in for real
/// entrance-fee/menu-price data, which isn't available without a paid API
/// (Google Places pricing data requires billing, same constraint as
/// elsewhere in this app). Mode-independent: whether you drove, walked, or
/// bussed there, an RM25 meal still costs RM25.
class PlaceCostEstimator {
  PlaceCostEstimator._();

  static double forDestinationCategory(DestinationCategory category) {
    switch (category) {
      case DestinationCategory.restaurant:
        return 25;
      case DestinationCategory.craft:
        return 20;
      case DestinationCategory.cafe:
        return 12;
      case DestinationCategory.attraction:
        return 15;
      case DestinationCategory.museum:
        return 10;
      case DestinationCategory.art:
        return 10;
      case DestinationCategory.waterfall:
        return 5;
      case DestinationCategory.heritageSite:
        return 5;
      case DestinationCategory.viewpoint:
        return 3;
      case DestinationCategory.park:
        return 2;
      case DestinationCategory.beach:
        return 0;
      case DestinationCategory.themePark:
        return 80;
      case DestinationCategory.island:
        return 30; // boat/ferry transfer + entrance
      case DestinationCategory.mountain:
        return 10; // trail/permit fee
      case DestinationCategory.mall:
        return 0; // free entry — spending there is discretionary, not a visit cost
    }
  }
}
