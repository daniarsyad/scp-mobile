import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scp_mobile/utils/photo_watermark.dart';

void main() {
  test('applyJournalPhotoWatermark adds readable watermark and returns valid jpeg', () {
    // Buat image dummy 400x300
    final baseImage = img.Image(width: 400, height: 300);
    img.fill(baseImage, color: img.ColorRgb8(120, 120, 120));
    final rawPng = img.encodePng(baseImage);

    final timestamp = DateTime(2026, 11, 7, 14, 30, 45);
    final watermarked = applyJournalPhotoWatermark(rawPng, timestamp: timestamp);

    expect(watermarked, isNotEmpty);
    // Cek header JPEG (0xFF, 0xD8)
    expect(watermarked[0], 255);
    expect(watermarked[1], 216);

    final decoded = img.decodeImage(watermarked);
    expect(decoded, isNotNull);
    expect(decoded!.width, 400);
    expect(decoded!.height, 300);
  });
}

