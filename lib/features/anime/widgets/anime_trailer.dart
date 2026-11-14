import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// A compact, accessible trailer link for anime detail pages.
class AnimeTrailerTile extends StatelessWidget {
  const AnimeTrailerTile({required this.trailerUrl, super.key});

  final String trailerUrl;

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(trailerUrl.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The trailer link is unavailable.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.play_arrow_rounded),
        ),
        title: const Text('Watch trailer'),
        subtitle: const Text('Opens the official trailer outside Pubget'),
        trailing: const Icon(Icons.open_in_new_rounded),
        onTap: () => _open(context),
      ),
    );
  }
}
