import 'dart:io';

import 'package:collab/features/travel_prep/model/travel_document.dart';
import 'package:collab/features/travel_prep/model/travel_document_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    storagePath: 'user-a/doc-1/doc-1.pdf',
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
    expect(restored.storagePath, document.storagePath);
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

  test('document metadata is isolated by authenticated user ID', () async {
    SharedPreferences.setMockInitialValues({});
    final firstUserRepository = TravelDocumentRepository(userId: 'user-a');
    final secondUserRepository = TravelDocumentRepository(userId: 'user-b');

    await firstUserRepository.save([document]);

    expect(await firstUserRepository.load(), hasLength(1));
    expect(await secondUserRepository.load(), isEmpty);
  });

  test('rejects a file larger than the 10 MB upload limit', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'vault-size-test-',
    );
    final oversizedFile = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}large.pdf',
    );
    await oversizedFile.writeAsBytes(
      List<int>.filled(TravelDocumentRepository.maxFileSizeBytes + 1, 0),
    );
    final repository = TravelDocumentRepository(userId: 'user-a');

    await expectLater(
      repository.importFile(
        sourcePath: oversizedFile.path,
        originalFileName: 'large.pdf',
        displayName: 'Large PDF',
        category: 'Other',
        currentDocuments: const [],
      ),
      throwsA(isA<FileSystemException>()),
    );

    await temporaryDirectory.delete(recursive: true);
  });

  test('free-tier safeguards remain conservative', () {
    expect(TravelDocumentRepository.maxFileSizeBytes, 10 * 1024 * 1024);
    expect(TravelDocumentRepository.maxUserStorageBytes, 50 * 1024 * 1024);
    expect(TravelDocumentRepository.maxVaultStorageBytes, 250 * 1024 * 1024);
  });
}
