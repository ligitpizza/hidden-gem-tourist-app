/// Route paths for the bottom-nav tabs (the shell's branches).
class ShellRoutes {
  ShellRoutes._();

  static const map = '/';
  static const explore = '/explore';
  static const assistant = '/assistant';
  static const saved = '/saved';
  static const profile = '/profile';
  static const travelPrep = '/travel-prep';
  static const checklist = '/travel-prep/checklist';
  static const ecoPartners = '/travel-prep/eco-partners';
  static const documentVault = '/travel-prep/document-vault';

  // Module 6 — Gamification & Travel Journal. Check-in isn't linked from
  // here yet (see DestinationDetailScreen) — it still needs to be wired
  // into the existing map screen.
  static const journal = '/journal';
  static const journalBadges = '/journal/badges';
  static const journalEntries = '/journal/entries';
  static const journalQuizzes = '/journal/quizzes';
  static const journalHistory = '/journal/history';
}
