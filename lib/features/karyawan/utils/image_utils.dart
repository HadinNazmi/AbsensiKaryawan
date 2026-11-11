import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Kompres dan sesuaikan ukuran foto selfie:
/// Lebar maksimal 800 px, format JPEG, target ukuran ≤ 500 KB
Uint8List processSelfiePhoto(Uint8List rawBytes) {
  final image = img.decodeImage(rawBytes);
  if (image == null) return rawBytes;

  img.Image processed = image;
  if (image.width > 800) {
    processed = img.copyResize(image, width: 800);
  }

  // Kualitas 80 menghasilkan foto tajam dengan ukuran ~100-250 KB
  final jpgBytes = img.encodeJpg(processed, quality: 80);
  return Uint8List.fromList(jpgBytes);
}

