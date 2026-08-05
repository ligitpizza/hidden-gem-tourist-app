import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'travel_document.dart';

class TravelDocumentRepository {
  static const maxFileSizeBytes = 10 * 1024 * 1024;

  TravelDocumentRepository({String? userId})
    : userId =
          userId ??
          Supabase.instance.client.auth.currentUser?.id ??
          (throw StateError('A signed-in user is required.'));

  final String userId;

  String get _metadataKey => 'travel_vault_documents_v2_$userId';

  Future<List<TravelDocument>> load() async {
    final preferences = await SharedPreferences.getInstance();
    try {
      final documents = TravelDocument.decodeList(
        preferences.getString(_metadataKey),
      );
      documents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return documents;
    } on Object {
      return [];
    }
  }

  Future<TravelDocument> importFile({
    required String sourcePath,
    required String originalFileName,
    required String displayName,
    required String category,
    required List<TravelDocument> currentDocuments,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('Selected file is unavailable.');
    }
    final sourceSize = await source.length();
    if (sourceSize > maxFileSizeBytes) {
      throw const FileSystemException(
        'The selected file exceeds the 10 MB upload limit.',
      );
    }

    final directory = await _vaultDirectory();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final extension = _extensionOf(originalFileName);
    final storedName = extension.isEmpty ? id : '$id.$extension';
    final destination = File(
      '${directory.path}${Platform.pathSeparator}$storedName',
    );
    await source.copy(destination.path);
    final document = TravelDocument(
      id: id,
      displayName: displayName.trim(),
      category: category,
      originalFileName: originalFileName,
      storedPath: destination.path,
      extension: extension,
      fileSize: sourceSize,
      createdAt: DateTime.now(),
    );

    try {
      await save([document, ...currentDocuments]);
      return document;
    } on Object {
      if (await destination.exists()) {
        await destination.delete();
      }
      rethrow;
    }
  }

  Future<void> save(List<TravelDocument> documents) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _metadataKey,
      TravelDocument.encodeList(documents),
    );
    if (!saved) {
      throw const FileSystemException('Could not save vault metadata.');
    }
  }

  Future<void> delete(
    TravelDocument document,
    List<TravelDocument> remaining,
  ) async {
    await deleteMany([document], remaining);
  }

  Future<void> deleteMany(
    List<TravelDocument> documents,
    List<TravelDocument> remaining,
  ) async {
    final failures = <TravelDocument>[];
    Object? firstError;
    for (final document in documents) {
      try {
        final file = File(document.storedPath);
        if (await file.exists()) {
          await file.delete();
        }
      } on Object catch (error) {
        failures.add(document);
        firstError ??= error;
      }
    }
    if (failures.isNotEmpty) {
      throw VaultFileDeleteException(failures, firstError);
    }
    await save(remaining);
  }

  Future<Directory> _vaultDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}travel_vault${Platform.pathSeparator}$userId',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    return dot < 0 || dot == name.length - 1
        ? ''
        : name.substring(dot + 1).toLowerCase();
  }
}

class VaultFileDeleteException implements Exception {
  const VaultFileDeleteException(this.documents, this.cause);

  final List<TravelDocument> documents;
  final Object? cause;

  @override
  String toString() =>
      'Could not remove ${documents.length} stored file(s): $cause';
}
