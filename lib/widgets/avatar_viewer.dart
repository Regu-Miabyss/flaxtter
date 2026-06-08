import 'package:flutter/material.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/utils/media_actions.dart';

String largeProfileImageUrl(String url) {
  return url.replaceAll('_normal', '_400x400').replaceAll('normal', '400x400');
}

class AvatarViewer extends StatelessWidget {
  final String imageUrl;

  const AvatarViewer({
    super.key,
    required this.imageUrl,
  });

  static Future<void> open(BuildContext context, {required String? imageUrl}) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Future.value();
    }
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => AvatarViewer(imageUrl: largeProfileImageUrl(imageUrl)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: l10n.saveImage,
            icon: const Icon(Icons.download),
            onPressed: () => saveImage(context, imageUrl),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) {
                return child;
              }
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 96, color: Colors.white54),
          ),
        ),
      ),
    );
  }
}
