import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'repo.dart';

/// Phone cameras make 3 to 8 MB photos. Resize to at most 1600 px on the long
/// side and re-encode as JPEG so uploads are small and fast on mobile data.
/// The same input always gives the same output, so duplicate detection by
/// hash still works.
Uint8List compressPhoto(Uint8List bytes, {int maxSide = 1600, int quality = 80}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw AppError('Foto tidak bisa dibaca. Pakai file JPG atau PNG.');
  }
  var im = img.bakeOrientation(decoded);
  if (im.width > maxSide || im.height > maxSide) {
    im = im.width >= im.height
        ? img.copyResize(im, width: maxSide)
        : img.copyResize(im, height: maxSide);
  }
  return Uint8List.fromList(img.encodeJpg(im, quality: quality));
}
