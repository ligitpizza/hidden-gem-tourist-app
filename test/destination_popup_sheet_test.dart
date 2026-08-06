import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:collab/features/destination_exploration/model/map_destination.dart';
import 'package:collab/features/destination_exploration/view/widgets/destination_popup_sheet.dart';
import 'package:collab/shared/models/hidden_gem.dart';

class _TestHttpClientRequest implements HttpClientRequest {
  final Completer<HttpClientResponse> _completer = Completer();

  @override
  Future<HttpClientResponse> close() {
    _completer.complete(_TestHttpClientResponse());
    return _completer.future;
  }

  @override
  void noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  static final Uint8List _pngData = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
    0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0x99, 0x63, 0xF8, 0x0F, 0x00, 0x00,
    0x01, 0x01, 0x01, 0x00, 0x1B, 0xB6, 0xEE, 0x56, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,
    0xAE, 0x42, 0x60, 0x82,
  ]);

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream.value(_pngData).listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  int get statusCode => 200;

  @override
  int get contentLength => _pngData.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.decompressed;

  @override
  void noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestHttpClient implements HttpClient {
  bool _autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _TestHttpClientRequest();

  @override
  bool get autoUncompress => _autoUncompress;

  @override
  set autoUncompress(bool value) {
    _autoUncompress = value;
  }

  @override
  void noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _TestHttpClient();
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _TestHttpOverrides();
  });

  tearDownAll(() {
    HttpOverrides.global = null;
  });

  testWidgets('shows a placeholder icon when there are no images', (tester) async {
    const destination = MapDestination(
      id: '1',
      name: 'Test Place',
      description: 'A place worth visiting.',
      category: HiddenGemCategory.nature,
      location: LatLng(5.4, 100.3),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DestinationPopupSheet(destination: destination)),
      ),
    );

    expect(find.text('Test Place'), findsOneWidget);
    expect(find.text('A place worth visiting.'), findsOneWidget);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('renders an image per URL when images are present', (tester) async {
    const destination = MapDestination(
      id: '2',
      name: 'Gem Spot',
      description: 'Nice.',
      category: HiddenGemCategory.food,
      location: LatLng(5.4, 100.3),
      imageUrls: ['https://example.com/a.jpg', 'https://example.com/b.jpg'],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DestinationPopupSheet(destination: destination)),
      ),
    );

    expect(find.byType(Image), findsNWidgets(2));
    expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
  });
}
