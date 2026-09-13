import 'package:flutter/widgets.dart';

/// Notifies which of the Journal branch's "More menu" screens (if any) —
/// Badges/Quizzes/History/Friends — is currently on screen, or `null` when
/// none of them are. `AppBottomNavBar` listens to this so its collapsed
/// "More" nav slot can mirror what's actually showing.
///
/// This is driven purely by [JournalMoreScreenAnnouncer]'s own mount/
/// dispose lifecycle below, not by go_router's `state.uri` or a
/// `NavigatorObserver` — two earlier attempts at this same feature tried
/// both and failed: `state.uri` doesn't reliably refresh on `goBranch()`,
/// and a `NavigatorObserver` attached to the Journal branch only fires
/// when the push is initiated while that branch is already active —
/// `context.push()` from the bottom nav bar (a different branch's context,
/// which is how the More menu is actually used) switches the active shell
/// branch without ever notifying that branch's own observers. Reading the
/// screen's own widget lifecycle instead sidesteps both problems, since it
/// fires correctly no matter how go_router routed the push internally.
final ValueNotifier<String?> journalMoreScreenNotifier =
    ValueNotifier<String?>(null);

/// Wraps one of the Journal branch's "More menu" screens (in its GoRoute's
/// `builder:`) so it announces itself as the active one for as long as
/// it's mounted, and clears that back to `null` on dispose — works the
/// same whether the wrapped screen itself is Stateless or Stateful.
class JournalMoreScreenAnnouncer extends StatefulWidget {
  const JournalMoreScreenAnnouncer({
    super.key,
    required this.name,
    required this.child,
  });

  final String name;
  final Widget child;

  @override
  State<JournalMoreScreenAnnouncer> createState() =>
      _JournalMoreScreenAnnouncerState();
}

class _JournalMoreScreenAnnouncerState
    extends State<JournalMoreScreenAnnouncer> {
  @override
  void initState() {
    super.initState();
    journalMoreScreenNotifier.value = widget.name;
  }

  @override
  void dispose() {
    // Only clear it if it's still ours — guards against this screen's
    // dispose running after a different one has already taken over (it
    // shouldn't happen given these are mutually exclusive routes, but
    // clearing unconditionally could otherwise wipe out a legitimate
    // newer value from a race in the pop/push ordering).
    if (journalMoreScreenNotifier.value == widget.name) {
      journalMoreScreenNotifier.value = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
