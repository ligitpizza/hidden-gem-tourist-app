import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'travel_document.dart';

class TravelDocumentRepository {
  static const _metadataKey = 'travel_vault_documents_v1';

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
      fileSize: await destination.length(),
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
    final file = File(document.storedPath);
    if (await file.exists()) {
      await file.delete();
    }
    await save(remaining);
  }

  Future<Directory> _vaultDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}travel_vault',
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
