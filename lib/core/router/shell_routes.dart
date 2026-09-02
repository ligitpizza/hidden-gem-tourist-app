/// Route paths for the bottom-nav tabs (the shell's branches).
class ShellRoutes {
  ShellRoutes._();

  static const map = '/';
  static const explore = '/explore';
  static const assistant = '/assistant';
  static const saved = '/saved';
  static const profile = '/profile';
  static const travelAssistant = '/travel-assistant';
  static const checklist = '/travel-assistant/checklist';
  static const ecoPartners = '/travel-assistant/eco-partners';
  static const documentVault = '/travel-assistant/document-vault';

  // Compatibility for links created before the module rename.
  static const legacyTravelAssistant = '/travel-prep';
  static const legacyInterimAssistant = '/smart-assistant';

  // Module 6 — Gamification & Travel Journal. The Journal tab itself shows
  // the entries timeline directly; Badges/Quizzes/Check-in history are
  // pushed from the bottom nav's More menu instead of living on the tab.
  static const journal = '/journal';
  static const journalBadges = '/journal/badges';
  static const journalEntries = '/journal/entries';
  static const journalQuizzes = '/journal/quizzes';
  static const journalHistory = '/journal/history';
  static const journalFriends = '/journal/friends';
  static const culture = '/culture';
}
