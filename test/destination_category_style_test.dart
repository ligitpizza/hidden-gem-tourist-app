// test/destination_category_style_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:collab/features/destination_exploration/view/widgets/category_style.dart';
import 'package:collab/shared/models/hidden_gem.dart';

void main() {
  group('category styling', () {
    test('every category has a distinct color', () {
      final colors = HiddenGemCategory.values.map(categoryColor).toSet();
      expect(colors.length, HiddenGemCategory.values.length);
    });

    test('every category has a distinct icon', () {
      final icons = HiddenGemCategory.values.map(categoryIcon).toSet();
      expect(icons.length, HiddenGemCategory.values.length);
    });
  });
}
