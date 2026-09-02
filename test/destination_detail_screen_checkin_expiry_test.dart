// test/destination_detail_screen_checkin_expiry_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:collab/features/gamification_journal/controller/badge_controller.dart';
import 'package:collab/features/gamification_journal/controller/checkin_controller.dart';
import 'package:collab/features/gamification_journal/controller/journal_controller.dart';
import 'package:collab/features/gamification_journal/controller/quiz_controller.dart';
import 'package:collab/features/gamification_journal/model/check_in_model.dart';
import 'package:collab/features/gamification_journal/model/destination_model.dart';
import 'package:collab/features/gamification_journal/services/mock/mock_checkin_service.dart';
import 'package:collab/features/gamification_journal/view/checkin/destination_detail_screen.dart';

final _destination = DestinationModel(
  id: 'd1',
  name: 'Escape Penang',
  state: 'Penang',
  category: 'Nature',
  latitude: 5.4489,
  longitude: 100.2492,
  description: 'An outdoor adventure park.',
  imageUrl: 'https://example.com/img.png',
);

Widget _wrap(CheckInController checkInController) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CheckInController>.value(value: checkInController),
      ChangeNotifierProvider<QuizController>(create: (_) => QuizController(userId: 'u1')),
      ChangeNotifierProvider<BadgeController>(create: (_) => BadgeController(userId: 'u1')),
      ChangeNotifierProvider<JournalController>(create: (_) => JournalController(userId: 'u1')),
    ],
    child: MaterialApp(home: DestinationDetailScreen(destination: _destination)),
  );
}

void main() {
  testWidgets('Write a Review is locked once the check-in is older than the cooldown window', (tester) async {
    final checkInController = CheckInController(userId: 'u1')
      ..setHistoryForTesting([
        CheckInModel(
          id: 'c1',
          userId: 'u1',
          destinationId: 'd1',
          timestamp: DateTime.now().subtract(MockCheckInService.cooldownWindow + const Duration(hours: 1)),
          latitude: 5.4489,
          longitude: 100.2492,
        ),
      ]);

    // Not pumpAndSettle(): when isCheckedIn is true, the destination quiz
    // card auto-starts via QuizController, whose MockQuizService can't load
    // its question bank without a real Supabase connection (unavailable in
    // a unit test) and so never leaves its loading state — an indeterminate
    // CircularProgressIndicator that would hang pumpAndSettle forever. The
    // "Write a Review" button's enabled state is driven synchronously by
    // isCheckedIn in build(), so it's already correct after a couple of
    // pumps regardless of whether the (unrelated) quiz card ever resolves.
    await tester.pumpWidget(_wrap(checkInController));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final writeReviewFinder = find.text('Write a Review');
    expect(writeReviewFinder, findsOneWidget);
    final button = tester.widget<TextButton>(
      find.ancestor(of: writeReviewFinder, matching: find.byType(TextButton)).first,
    );
    expect(button.onPressed, isNull, reason: 'a check-in older than the cooldown window must not unlock reviews');
  });

  testWidgets('Write a Review is unlocked for a check-in within the cooldown window', (tester) async {
    final checkInController = CheckInController(userId: 'u1')
      ..setHistoryForTesting([
        CheckInModel(
          id: 'c1',
          userId: 'u1',
          destinationId: 'd1',
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          latitude: 5.4489,
          longitude: 100.2492,
        ),
      ]);

    // Not pumpAndSettle(): when isCheckedIn is true, the destination quiz
    // card auto-starts via QuizController, whose MockQuizService can't load
    // its question bank without a real Supabase connection (unavailable in
    // a unit test) and so never leaves its loading state — an indeterminate
    // CircularProgressIndicator that would hang pumpAndSettle forever. The
    // "Write a Review" button's enabled state is driven synchronously by
    // isCheckedIn in build(), so it's already correct after a couple of
    // pumps regardless of whether the (unrelated) quiz card ever resolves.
    await tester.pumpWidget(_wrap(checkInController));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final writeReviewFinder = find.text('Write a Review');
    expect(writeReviewFinder, findsOneWidget);
    final button = tester.widget<TextButton>(
      find.ancestor(of: writeReviewFinder, matching: find.byType(TextButton)).first,
    );
    expect(button.onPressed, isNotNull);
  });
}
