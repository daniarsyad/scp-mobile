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

  final origin = ApiConfig.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
  final isLocalServer = origin.contains('127.0.0.1') ||
      origin.contains('localhost') ||
      origin.contains('10.0.2.2');

  if (text.startsWith('http://') || text.startsWith('https://')) {
    if (!isLocalServer &&
        text.contains('/storage/') &&
        !text.contains('/public/storage/')) {
      return text.replaceFirst('/storage/', '/public/storage/');
    }
    return text;
  }

  var cleanPath = text;
  while (cleanPath.startsWith('/')) {
    cleanPath = cleanPath.substring(1);
  }
  if (cleanPath.startsWith('public/storage/')) {
    cleanPath = cleanPath.substring('public/storage/'.length);
  } else if (cleanPath.startsWith('storage/')) {
    cleanPath = cleanPath.substring('storage/'.length);
  }

  if (cleanPath.isEmpty) return null;
  if (isLocalServer) {
    return '$origin/storage/$cleanPath';
  }
  return '$origin/public/storage/$cleanPath';
}

String? alternateMediaUrl(String url) {
  if (url.contains('/public/storage/')) {
    return url.replaceFirst('/public/storage/', '/storage/');
  }
  if (url.contains('/storage/')) {
    return url.replaceFirst('/storage/', '/public/storage/');
  }
  return null;
}

Widget buildNetworkMediaImage(
  String url, {
  BoxFit fit = BoxFit.contain,
  double? width,
  double? height,
  String errorText = 'Berkas tidak bisa ditampilkan.',
}) {
  final altUrl = alternateMediaUrl(url);
  return Image.network(
    url,
    fit: fit,
    width: width,
    height: height,
    errorBuilder: (_, _, _) {
      if (altUrl != null && altUrl != url) {
        return Image.network(
          altUrl,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, _, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              errorText,
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          errorText,
          textAlign: TextAlign.center,
        ),
      );
    },
  );
}

String? firstMedia(Map item, List<String> keys) {
  for (final key in keys) {
    final url = resolveMedia(item[key]);
    if (url != null) return url;
  }
  return null;
}

const suratKeys = [
  'document_path',
  'document_url',
  'document',
  'file_path',
  'file_url',
  'file',
  'surat',
  'attachment',
  'proof',
];

const photoKeys = [
  'photo_path',
  'photo_url',
  'photo',
  'image_path',
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
            child: buildNetworkMediaImage(
              url,
              fit: BoxFit.contain,
              errorText: 'Berkas tidak bisa ditampilkan.',
            ),
          ),
        ],
      ),
    ),
  );
}
