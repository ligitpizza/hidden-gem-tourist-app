import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

/// Distinguishes a real "download to device" from "share" for exported
/// itinerary images. `gal` only has a gallery API on Android/iOS — on any
/// other platform (desktop, web) there's no equivalent, so downloading
/// falls back to the share sheet there, where the OS itself offers a
/// "Save As" option.
class ImageExportService {
  ImageExportService._();

  static bool get _supportsGallerySave => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Saves [bytes] straight to the device's photo gallery — no share sheet,
  /// no picking an app. Returns `true` if it actually landed in the
  /// gallery, or `false` if this platform has no gallery API and it fell
  /// back to the share sheet instead (so callers can word their
  /// confirmation message correctly). Throws if permission is denied.
  static Future<bool> downloadToGallery(Uint8List bytes, {required String fileName}) async {
    if (_supportsGallerySave) {
      await Gal.putImageBytes(bytes, name: fileName);
      return true;
    }
    final file = XFile.fromData(bytes, name: '$fileName.png', mimeType: 'image/png');
    await Share.shareXFiles(
      [file],
      subject: 'Save image',
      text: 'Save this image to your device.',
    );
    return false;
  }
}
