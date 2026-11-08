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
    expect(decoded.height, 300);
  });

  test('flipImageHorizontal un-mirrors image horizontally', () {
    // Buat gambar 2x1 dengan pixel kiri merah, pixel kanan biru
    final testImage = img.Image(width: 2, height: 1);
    testImage.setPixelRgba(0, 0, 255, 0, 0, 255); // Kiri merah
    testImage.setPixelRgba(1, 0, 0, 0, 255, 255); // Kanan biru
    final rawPng = img.encodePng(testImage);

    final flippedBytes = flipImageHorizontal(rawPng);
    final flipped = img.decodeImage(flippedBytes);
    expect(flipped, isNotNull);
    expect(flipped!.width, 2);
    expect(flipped.height, 1);

    // Setelah di-flip horizontal, pixel kiri harus biru (R rendah), pixel kanan harus merah (R tinggi)
    final pLeft = flipped.getPixel(0, 0);
    final pRight = flipped.getPixel(1, 0);
    expect(pLeft.r < pRight.r, isTrue);
  });
}


