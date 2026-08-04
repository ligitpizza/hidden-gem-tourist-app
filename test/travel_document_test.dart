import 'package:collab/features/travel_prep/model/travel_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final document = TravelDocument(
    id: 'doc-1',
    displayName: 'Passport',
    category: 'Passports',
    originalFileName: 'passport.pdf',
    storedPath: '/vault/doc-1.pdf',
    extension: 'pdf',
    fileSize: 2048,
    createdAt: DateTime.utc(2026, 8, 4),
  );

  test('serializes and restores persistent document metadata', () {
    final restored = TravelDocument.decodeList(
      TravelDocument.encodeList([document]),
    ).single;

    expect(restored.id, document.id);
    expect(restored.displayName, document.displayName);
    expect(restored.category, document.category);
    expect(restored.originalFileName, document.originalFileName);
    expect(restored.storedPath, document.storedPath);
    expect(restored.fileSize, document.fileSize);
    expect(restored.createdAt, document.createdAt);
  });

  test('recognizes internal viewer file types', () {
    expect(document.isPdf, isTrue);
    expect(document.isImage, isFalse);

    final image = TravelDocument(
      id: 'doc-2',
      displayName: 'Visa photo',
      category: 'Visas',
      originalFileName: 'visa.webp',
      storedPath: '/vault/doc-2.webp',
      extension: 'WEBP',
      fileSize: 1024,
      createdAt: DateTime.utc(2026, 8, 4),
    );
    expect(image.isImage, isTrue);
    expect(image.isPdf, isFalse);
  });

  test('metadata edits preserve the stored file identity', () {
    final edited = document.copyWith(
      displayName: 'Updated Passport',
      category: 'Identification',
    );

    expect(edited.displayName, 'Updated Passport');
    expect(edited.category, 'Identification');
    expect(edited.id, document.id);
    expect(edited.storedPath, document.storedPath);
    expect(edited.originalFileName, document.originalFileName);
  });
}
