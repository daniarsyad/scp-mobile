import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../theme/scp_theme.dart';

String? resolveMedia(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map) {
    return resolveMedia(raw['url'] ?? raw['path'] ?? raw['file'] ?? raw['document']);
  }
  final text = raw.toString().trim();
  if (text.isEmpty || text == 'null') return null;
  if (text.startsWith('http://') || text.startsWith('https://')) return text;
  final origin = ApiConfig.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
  if (text.startsWith('/')) return '$origin$text';
  return '$origin/storage/$text';
}

String? firstMedia(Map item, List<String> keys) {
  for (final key in keys) {
    final url = resolveMedia(item[key]);
    if (url != null) return url;
  }
  return null;
}

const suratKeys = [
  'document_url',
  'document',
  'file_url',
  'file',
  'surat',
  'attachment',
  'proof',
];

const photoKeys = [
  'photo_url',
  'photo',
  'image_url',
  'image',
  'foto',
];

void showMediaPreview(BuildContext context, String url, {String title = 'Lampiran'}) {
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: ScpColors.surface,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Berkas tidak bisa ditampilkan.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
