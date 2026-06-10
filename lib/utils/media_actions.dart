import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const _imageAlbumName = 'Flaxtter';
const _videoAlbumName = 'Flaxtter';

Future<void> showMediaActionSnackBar(BuildContext context, String message) {
  if (!context.mounted) {
    return Future.value();
  }
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  return Future.value();
}

Future<bool> copyPngFileToClipboard(File file) async {
  if (!Platform.isLinux) {
    return false;
  }

  try {
    final process = await Process.start('wl-copy', ['-t', 'image/png']);
    process.stdin.add(file.readAsBytesSync());
    await process.stdin.close();
    if (await process.exitCode == 0) {
      return true;
    }
  } catch (_) {}

  try {
    final xclip = await Process.run('xclip', [
      '-selection',
      'clipboard',
      '-t',
      'image/png',
      '-i',
      file.path,
    ]);
    if (xclip.exitCode == 0) {
      return true;
    }
  } catch (_) {}

  return false;
}

Future<Uint8List> downloadMediaBytes(String url) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('HTTP ${response.statusCode}');
  }
  return response.bodyBytes;
}

String _extensionFromUrl(String url) {
  final ext = p.extension(Uri.parse(url).path);
  if (ext.isNotEmpty && ext.length <= 5) {
    return ext;
  }
  return '.jpg';
}

Future<void> _ensureGalleryAccess() async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    return;
  }
  if (!await Gal.hasAccess(toAlbum: true)) {
    final granted = await Gal.requestAccess(toAlbum: true);
    if (!granted) {
      throw Exception('Gallery access denied');
    }
  }
}

Future<String> saveImageBytesToAlbum(
  Uint8List bytes, {
  String? extension,
  String? baseName,
}) async {
  final safeExt = extension ?? '.jpg';
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final name = baseName ?? 'flaxtter_$stamp';
  final fileName = '$name$safeExt';

  if (Platform.isAndroid || Platform.isIOS) {
    await _ensureGalleryAccess();
    await Gal.putImageBytes(bytes, album: _imageAlbumName, name: name);
    if (Platform.isAndroid) {
      return 'Pictures/$_imageAlbumName/$fileName';
    }
    return '$_imageAlbumName/$fileName';
  }

  final picturesRoot = Platform.environment['XDG_PICTURES_DIR'] ??
      p.join(Platform.environment['HOME'] ?? '', 'Pictures');
  final directory = Directory(p.join(picturesRoot, _imageAlbumName));
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
  final file = File(p.join(directory.path, fileName));
  await file.writeAsBytes(bytes);
  return file.path;
}

Future<File> downloadMediaFile(String url, {String? fileName}) async {
  final bytes = await downloadMediaBytes(url);
  final tempDir = await getTemporaryDirectory();
  final ext = _extensionFromUrl(url);
  final name = fileName ?? 'flaxtter_${DateTime.now().millisecondsSinceEpoch}$ext';
  final file = File(p.join(tempDir.path, name));
  await file.writeAsBytes(bytes);
  return file;
}

Future<void> copyText(BuildContext context, String text, String message) async {
  await Clipboard.setData(ClipboardData(text: text));
  await showMediaActionSnackBar(context, message);
}

Future<String> saveVideoBytesToAlbum(String filePath, {String? baseName}) async {
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final name = baseName ?? 'flaxtter_$stamp';
  final fileName = '$name.mp4';

  if (Platform.isAndroid || Platform.isIOS) {
    await _ensureGalleryAccess();
    await Gal.putVideo(filePath, album: _videoAlbumName);
    if (Platform.isAndroid) {
      return 'Movies/$_videoAlbumName/$fileName';
    }
    return '$_videoAlbumName/$fileName';
  }

  final videosRoot = Platform.environment['XDG_VIDEOS_DIR'] ??
      p.join(Platform.environment['HOME'] ?? '', 'Videos');
  final directory = Directory(p.join(videosRoot, _videoAlbumName));
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
  final target = File(p.join(directory.path, fileName));
  await File(filePath).copy(target.path);
  return target.path;
}

Future<void> saveVideo(BuildContext context, String videoUrl) async {
  final l10n = AppLocalizations.of(context);
  try {
    final file = await downloadMediaFile(
      videoUrl,
      fileName: 'flaxtter_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );
    final savedPath = await saveVideoBytesToAlbum(file.path);
    if (!context.mounted) {
      return;
    }
    await showMediaActionSnackBar(context, l10n.videoSaved(savedPath));
  } catch (e) {
    if (!context.mounted) {
      return;
    }
    await showMediaActionSnackBar(context, l10n.actionFailed(e.toString()));
  }
}

Future<void> saveImage(BuildContext context, String imageUrl) async {
  final l10n = AppLocalizations.of(context);
  try {
    final bytes = await downloadMediaBytes(imageUrl);
    final savedPath = await saveImageBytesToAlbum(
      bytes,
      extension: _extensionFromUrl(imageUrl),
    );
    if (!context.mounted) {
      return;
    }
    await showMediaActionSnackBar(context, l10n.imageSaved(savedPath));
  } catch (e) {
    if (!context.mounted) {
      return;
    }
    await showMediaActionSnackBar(context, l10n.actionFailed(e.toString()));
  }
}

Future<void> shareImage(BuildContext context, String imageUrl, {String? text}) async {
  final l10n = AppLocalizations.of(context);
  try {
    final file = await downloadMediaFile(imageUrl);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: text));
  } catch (e) {
    if (!context.mounted) {
      return;
    }
    await showMediaActionSnackBar(context, l10n.actionFailed(e.toString()));
  }
}

Future<void> copyImageUrl(BuildContext context, String imageUrl) async {
  final l10n = AppLocalizations.of(context);
  await copyText(context, imageUrl, l10n.imageLinkCopied);
}

Future<void> copyStatusLink(BuildContext context, String link) async {
  final l10n = AppLocalizations.of(context);
  await copyText(context, link, l10n.linkCopied);
}

Future<void> showTweetImageContextMenu(
  BuildContext context, {
  required String imageUrl,
  String? statusUrl,
}) async {
  final l10n = AppLocalizations.of(context);
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.download),
            title: Text(l10n.saveImage),
            onTap: () => Navigator.pop(context, 'save'),
          ),
          ListTile(
            leading: const Icon(Icons.image),
            title: Text(l10n.copyImage),
            onTap: () => Navigator.pop(context, 'copyImage'),
          ),
          if (statusUrl != null)
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(l10n.copyLink),
              onTap: () => Navigator.pop(context, 'copyLink'),
            ),
        ],
      ),
    ),
  );

  if (!context.mounted || action == null) {
    return;
  }
  switch (action) {
    case 'save':
      await saveImage(context, imageUrl);
    case 'copyImage':
      await copyImageUrl(context, imageUrl);
    case 'copyLink':
      if (statusUrl != null) {
        await copyStatusLink(context, statusUrl);
      }
  }
}
