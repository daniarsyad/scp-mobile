import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Memberikan watermark hari, tanggal, dan jam secara real-time pada foto
/// di pojok kiri bawah.
Uint8List applyJournalPhotoWatermark(List<int> rawBytes, {DateTime? timestamp}) {
  try {
    final image = img.decodeImage(Uint8List.fromList(rawBytes));
    if (image == null) {
      return Uint8List.fromList(rawBytes);
    }

    final now = timestamp ?? DateTime.now();

    const days = [
      '',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu'
    ];
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des'
    ];

    final dayName = days[now.weekday];
    final day = now.day.toString().padLeft(2, '0');
    final monthName = months[now.month];
    final year = now.year.toString();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');

    final line1 = '$dayName, $day $monthName $year';
    final line2 = '$hour:$minute:$second WIB';

    // Pilih font berdasarkan resolusi gambar agar proporsional
    final img.BitmapFont font;
    final int lineHeight;
    final int boxPadX;
    final int boxPadY;
    final int margin;

    if (image.width >= 1200 || image.height >= 1200) {
      // Resolusi besar (kamera standar smartphone)
      font = img.arial48;
      lineHeight = 56;
      boxPadX = 32;
      boxPadY = 24;
      margin = 36;
    } else if (image.width >= 600 || image.height >= 600) {
      // Resolusi sedang
      font = img.arial24;
      lineHeight = 28;
      boxPadX = 18;
      boxPadY = 14;
      margin = 20;
    } else {
      // Resolusi kecil
      font = img.arial14;
      lineHeight = 16;
      boxPadX = 10;
      boxPadY = 8;
      margin = 12;
    }

    // Perkiraan lebar teks terpanjang
    final longestCharCount = line1.length > line2.length ? line1.length : line2.length;
    final charWidth = font == img.arial48 ? 26 : (font == img.arial24 ? 14 : 8);
    final boxWidth = (longestCharCount * charWidth) + (boxPadX * 2);
    final boxHeight = (lineHeight * 2) + (boxPadY * 2);

    final boxX = margin;
    final boxY = image.height - boxHeight - margin;

    // Pastikan koordinat valid di dalam dimensi gambar
    if (boxY >= 0 && boxX >= 0 && (boxX + boxWidth) <= image.width) {
      // Background box semi-transparan (hitam transparan 70%)
      img.fillRect(
        image,
        x1: boxX,
        y1: boxY,
        x2: boxX + boxWidth,
        y2: boxY + boxHeight,
        color: img.ColorRgba8(0, 0, 0, 180),
      );

      // Baris 1: Hari, Tanggal (Teks Putih)
      img.drawString(
        image,
        line1,
        font: font,
        x: boxX + boxPadX,
        y: boxY + boxPadY,
        color: img.ColorRgb8(255, 255, 255),
      );

      // Baris 2: Jam:Menit:Detik WIB (Teks Kuning Emas agar kontras dan terbaca jelas)
      img.drawString(
        image,
        line2,
        font: font,
        x: boxX + boxPadX,
        y: boxY + boxPadY + lineHeight,
        color: img.ColorRgb8(255, 220, 0),
      );
    }

    return Uint8List.fromList(img.encodeJpg(image, quality: 85));
  } catch (_) {
    // Jika format tidak dikenali atau error saat proses watermark, kembalikan bytes asli
    return Uint8List.fromList(rawBytes);
  }
}

