import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/router/shell_routes.dart';
import '../../../shared/widgets/app_header.dart';
import '../model/travel_document.dart';

class TravelDocumentViewerScreen extends StatelessWidget {
  const TravelDocumentViewerScreen({
    super.key,
    required this.document,
    this.fallbackPath = ShellRoutes.travelAssistant,
  });

  final TravelDocument document;
  final String fallbackPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader.pushed(
        title: document.displayName,
        fallbackPath: fallbackPath,
      ),
      body: document.isPdf
          ? PdfViewer.file(
              document.storedPath,
              params: PdfViewerParams(
                loadingBannerBuilder: (_, _, _) => const _ViewerLoading(),
              ),
            )
          : Center(
              child: InteractiveViewer(
                minScale: .5,
                maxScale: 5,
                child: Image.file(
                  File(document.storedPath),
                  fit: BoxFit.contain,
                  frameBuilder: (context, child, frame, loadedSynchronously) =>
                      loadedSynchronously || frame != null
                      ? child
                      : const _ViewerLoading(),
                  errorBuilder: (_, _, _) => const _ViewerError(),
                ),
              ),
            ),
    );
  }
}

class _ViewerLoading extends StatelessWidget {
  const _ViewerLoading();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 14),
        Text('Loading document...'),
      ],
    ),
  );
}

class _ViewerError extends StatelessWidget {
  const _ViewerError();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, size: 52),
          SizedBox(height: 12),
          Text(
            'This image could not be displayed.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
