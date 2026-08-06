import 'dart:math';

import '../../model/cultural_fact_model.dart';
import '../../model/quiz_attempt_model.dart';
import '../../model/quiz_question_model.dart';

/// Phase 1 mock implementation of the cultural quiz challenge.
///
/// Questions are tagged by destination_id so fetchQuizForDestination()
/// mirrors the doc's "randomly select questions from categories based on
/// user checked-in hotspots" behaviour. In Phase 2 the question bank moves
/// to a Supabase table and this becomes a filtered SELECT + shuffle.
class MockQuizService {
  static const double passThresholdPercent = 60;

  final List<QuizAttemptModel> _attempts = [];
  int _idCounter = 0;
  final Random _random = Random();

  // 5 questions per destination — the quiz card on Destination Detail
  // always draws a 5-question set (60% pass threshold = 3 of 5 correct).
  final List<QuizQuestionModel> questionBank = [
    // Kellie's Castle (d001)
    QuizQuestionModel(
      id: 'q001',
      destinationId: 'd001',
      category: 'History',
      questionText: "Kellie's Castle was left unfinished after the death of:",
      options: ['A Portuguese trader', 'A Scottish planter', 'A Chinese merchant', 'A British governor'],
      correctOptionIndex: 1,
    ),
    QuizQuestionModel(
      id: 'q002',
      destinationId: 'd001',
      category: 'History',
      questionText: "Kellie's Castle is located in which Malaysian state?",
      options: ['Penang', 'Selangor', 'Perak', 'Kedah'],
      correctOptionIndex: 2,
    ),
    QuizQuestionModel(
      id: 'q009',
      destinationId: 'd001',
      category: 'History',
      questionText: "What was Kellie's Castle originally built to be?",
      options: ['A rubber plantation warehouse', "A private mansion for William Kellie Smith", 'A colonial government office', 'A Hindu temple'],
      correctOptionIndex: 1,
    ),
    QuizQuestionModel(
      id: 'q010',
      destinationId: 'd001',
      category: 'History',
      questionText: 'Near which town is Kellie\'s Castle located?',
      options: ['Batu Gajah', 'Taiping', 'Lumut', 'Kampar'],
      correctOptionIndex: 0,
    ),
    QuizQuestionModel(
      id: 'q011',
      destinationId: 'd001',
      category: 'History',
      questionText: 'Kellie\'s Castle was built during which era?',
      options: ['Post-independence 1960s', 'Japanese occupation', 'British colonial rubber boom', 'Portuguese colonial period'],
      correctOptionIndex: 2,
    ),
    // Semenggoh Nature Reserve (d002)
    QuizQuestionModel(
      id: 'q003',
      destinationId: 'd002',
      category: 'Nature',
      questionText: 'Semenggoh Nature Reserve is best known for rehabilitating:',
      options: ['Sun bears', 'Orangutans', 'Hornbills', 'Proboscis monkeys'],
      correctOptionIndex: 1,
    ),
    QuizQuestionModel(
      id: 'q004',
      destinationId: 'd002',
      category: 'Nature',
      questionText: 'Semenggoh Nature Reserve is near which Malaysian city?',
      options: ['Kota Kinabalu', 'Kuching', 'Miri', 'Sibu'],
      correctOptionIndex: 1,
    ),
    QuizQuestionModel(
      id: 'q012',
      destinationId: 'd002',
      category: 'Nature',
      questionText: 'Semenggoh Nature Reserve is located in which Malaysian state?',
      options: ['Sabah', 'Sarawak', 'Pahang', 'Johor'],
      correctOptionIndex: 1,
    ),
    QuizQuestionModel(
      id: 'q013',
      destinationId: 'd002',
      category: 'Nature',
      questionText: 'The best time to spot orangutans at feeding platforms is usually:',
      options: ['Midday only', 'Morning and afternoon feeding times', 'Only at night', 'Never — they roam freely off-site'],
      correctOptionIndex: 1,
    ),
    QuizQuestionModel(
      id: 'q014',
      destinationId: 'd002',
      category: 'Nature',
      questionText: 'Semenggoh mainly rehabilitates orangutans that were:',
      options: ['Born in the reserve', 'Orphaned, injured, or formerly captive', 'Relocated from zoos abroad', 'Bred for release quotas'],
      correctOptionIndex: 1,
    ),
    // Gua Tempurung (d003)
    QuizQuestionModel(
      id: 'q005',
      destinationId: 'd003',
      category: 'Nature',
      questionText: 'Gua Tempurung is primarily formed from which rock type?',
      options: ['Granite', 'Sandstone', 'Limestone', 'Basalt'],
      correctOptionIndex: 2,
    ),
    QuizQuestionModel(
      id: 'q015',
      destinationId: 'd003',
      category: 'Nature',
      questionText: 'Gua Tempurung is located in which Malaysian state?',
      options: ['Perak', 'Pahang', 'Kelantan', 'Negeri Sembilan'],
      correctOptionIndex: 0,
    ),
    QuizQuestionModel(
      id: 'q016',
      destinationId: 'd003',
      category: 'Nature',
      questionText: '"Gua" in Gua Tempurung is the Malay word for:',
      options: ['River', 'Cave', 'Mountain', 'Waterfall'],
      correctOptionIndex: 1,
    ),
    QuizQuestionModel(
      id: 'q017',
      destinationId: 'd003',
      category: 'Nature',
      questionText: 'Gua Tempurung is considered one of Malaysia\'s largest:',
      options: ['Limestone cave systems', 'Man-made reservoirs', 'Waterfall networks', 'Mangrove forests'],
      correctOptionIndex: 0,
    ),
    // Kampung Kuantan Firefly Park (d004)
    QuizQuestionModel(
      id: 'q006',
      destinationId: 'd004',
      category: 'Nature',
      questionText: 'Fireflies at Kampung Kuantan are typically viewed:',
      options: ['At sunrise', 'At noon', 'After dark, by boat', 'During monsoon storms'],
      correctOptionIndex: 2,
    ),
    QuizQuestionModel(
      id: 'q018',
      destinationId: 'd004',
      category: 'Nature',
      questionText: 'Kampung Kuantan Firefly Park is located in which state?',
      options: ['Selangor', 'Perak', 'Johor', 'Terengganu'],
      correctOptionIndex: 0,
    ),
    QuizQuestionModel(
      id: 'q019',
      destinationId: 'd004',
      category: 'Nature',
      questionText: 'Fireflies at Kampung Kuantan are famous for their:',
      options: ['Loud chirping sound', 'Synchronised flashing', 'Bright red glow', 'Migration across states'],
      correctOptionIndex: 1,
    ),
    QuizQuestionModel(
      id: 'q020',
      destinationId: 'd004',
      category: 'Nature',
      questionText: 'Fireflies here tend to cluster on which type of tree?',
      options: ['Berembang (mangrove apple)', 'Oil palm', 'Rubber', 'Durian'],
      correctOptionIndex: 0,
    ),
    // Jonker Walk (d005)
    QuizQuestionModel(
      id: 'q007',
      destinationId: 'd005',
      category: 'Food',
      questionText: 'Jonker Walk in Melaka is especially known for which cuisine?',
      options: ['Peranakan (Nyonya)', 'Kelantanese', 'Sabahan', 'Iban'],
      correctOptionIndex: 0,
    ),
    QuizQuestionModel(
      id: 'q008',
      destinationId: 'd005',
      category: 'Food',
      questionText: 'Melaka was historically an important stop for:',
      options: ['Silk Road caravans', 'Maritime spice traders', 'Gold prospectors', 'River loggers'],
      correctOptionIndex: 1,
    ),
    QuizQuestionModel(
      id: 'q021',
      destinationId: 'd005',
      category: 'Food',
      questionText: 'Jonker Walk\'s night market is best known for operating on:',
      options: ['Weekend evenings (Fri–Sun)', 'Weekday mornings only', 'Public holidays only', 'The first day of each month'],
      correctOptionIndex: 0,
    ),
    QuizQuestionModel(
      id: 'q022',
      destinationId: 'd005',
      category: 'History',
      questionText: 'Melaka\'s historic centre shares its UNESCO World Heritage status with:',
      options: ['George Town', 'Kuching', 'Ipoh', 'Kota Bharu'],
      correctOptionIndex: 0,
    ),
    QuizQuestionModel(
      id: 'q023',
      destinationId: 'd005',
      category: 'Food',
      questionText: 'Peranakan (Nyonya) cuisine reflects a blend of Malay and:',
      options: ['Chinese heritage', 'Arabic heritage', 'European heritage only', 'Japanese heritage'],
      correctOptionIndex: 0,
    ),
  ];

  final List<CulturalFactModel> culturalFacts = [
    CulturalFactModel(
      id: 'f001',
      factText: 'Malaysia has 13 states and 3 federal territories.',
      category: 'General',
    ),
    CulturalFactModel(
      id: 'f002',
      factText: 'Batik-making is a traditional textile art practised across Malaysia.',
      category: 'Culture',
    ),
    CulturalFactModel(
      id: 'f003',
      factText: 'Nasi lemak is widely regarded as one of Malaysia\'s national dishes.',
      category: 'Food',
    ),
    CulturalFactModel(
      id: 'f004',
      factText: 'George Town and Melaka are both UNESCO World Heritage Sites.',
      category: 'History',
    ),
    CulturalFactModel(
      id: 'f005',
      factText: 'Malaysia is home to some of the world\'s oldest rainforests.',
      category: 'Nature',
    ),
  ];

  /// Returns up to [count] random questions for a destination. Order is
  /// reshuffled on every call so reattempts don't repeat the same set.
  Future<List<QuizQuestionModel>> fetchQuizForDestination(
    String destinationId, {
    int count = 5,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final available = questionBank.where((q) => q.destinationId == destinationId).toList()
      ..shuffle(_random);

    return available.take(count).toList();
  }

  Future<CulturalFactModel> fetchDailyFact() async {
    await Future.delayed(const Duration(milliseconds: 150));
    final dayIndex = DateTime.now().difference(DateTime(2026, 1, 1)).inDays;
    return culturalFacts[dayIndex % culturalFacts.length];
  }

  /// Scores an attempt against the given questions and stores it.
  /// [selectedOptionIndexes] must be the same length and order as [questions].
  Future<QuizAttemptModel> submitAttempt({
    required String userId,
    required String destinationId,
    required List<QuizQuestionModel> questions,
    required List<int> selectedOptionIndexes,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    if (questions.length != selectedOptionIndexes.length) {
      throw ArgumentError('Answers must match the number of questions.');
    }

    var score = 0;
    for (var i = 0; i < questions.length; i++) {
      if (questions[i].correctOptionIndex == selectedOptionIndexes[i]) {
        score++;
      }
    }

    final percentage = questions.isEmpty ? 0 : (score / questions.length) * 100;

    final attempt = QuizAttemptModel(
      id: 'a${(_idCounter++).toString().padLeft(4, '0')}',
      userId: userId,
      destinationId: destinationId,
      score: score,
      totalQuestions: questions.length,
      passed: percentage >= passThresholdPercent,
      attemptedAt: DateTime.now(),
    );

    _attempts.add(attempt);
    return attempt;
  }

  Future<List<QuizAttemptModel>> fetchAttemptHistory(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _attempts.where((a) => a.userId == userId).toList()
      ..sort((a, b) => b.attemptedAt.compareTo(a.attemptedAt));
  }

  /// Counts completed quizzes for badge eligibility. Only the first passed
  /// attempt per destination counts, so retrying a failed quiz repeatedly
  /// doesn't inflate the "5 quizzes completed" badge progress.
  Future<int> countCompletedQuizzes(String userId) async {
    final passedDestinationIds = _attempts
        .where((a) => a.userId == userId && a.passed)
        .map((a) => a.destinationId)
        .toSet();
    return passedDestinationIds.length;
  }
}
