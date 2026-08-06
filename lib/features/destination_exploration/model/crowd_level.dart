/// How busy a destination typically is, self-reported per destination (not
/// crowd-sourced like the difficulty/accessibility ratings in Feature 4).
enum CrowdLevel { low, medium, high }

extension CrowdLevelX on CrowdLevel {
  String get label {
    switch (this) {
      case CrowdLevel.low:
        return 'Low';
      case CrowdLevel.medium:
        return 'Medium';
      case CrowdLevel.high:
        return 'High';
    }
  }
}

CrowdLevel crowdLevelFromDb(String? value) {
  switch (value) {
    case 'low':
      return CrowdLevel.low;
    case 'high':
      return CrowdLevel.high;
    case 'medium':
    default:
      return CrowdLevel.medium;
  }
}
