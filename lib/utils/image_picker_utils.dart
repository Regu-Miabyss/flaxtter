import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Twitter allows at most 4 images per tweet.
const maxComposeImages = 4;

String mimeTypeFromPath(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) {
    return 'image/png';
  }
  if (lower.endsWith('.gif')) {
    return 'image/gif';
  }
  if (lower.endsWith('.webp')) {
    return 'image/webp';
  }
  return 'image/jpeg';
}

/// Opens the platform image picker. Results are capped at [limit] images
/// even on platforms where the picker itself cannot enforce a limit.
Future<({List<Uint8List> bytes, List<String> mimeTypes})?> pickComposeImages({
  int limit = maxComposeImages,
}) async {
  final picker = ImagePicker();
  final files = await picker.pickMultiImage(limit: limit < 2 ? 2 : limit);
  if (files.isEmpty) {
    return null;
  }

  final bytes = <Uint8List>[];
  final mimeTypes = <String>[];
  for (final file in files.take(limit)) {
    bytes.add(await file.readAsBytes());
    mimeTypes.add(file.mimeType ?? mimeTypeFromPath(file.path));
  }
  return (bytes: bytes, mimeTypes: mimeTypes);
}
