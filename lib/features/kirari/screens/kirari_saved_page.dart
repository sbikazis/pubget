import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../app/app_router.dart';
import '../../../core/links/pubget_links.dart';
import '../data/kirari_repository.dart';

class KirariSavedPage extends StatefulWidget {
  const KirariSavedPage({super.key});

  @override
  State<KirariSavedPage> createState() => _KirariSavedPageState();
}

class _KirariSavedPageState extends State<KirariSavedPage> {
  List<KirariReel> _items = const <KirariReel>[];
  bool _loading = true;
  String? _error;
  final Set<String> _removing = <String>{};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await context.read<KirariRepository>().getSavedReels();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your saved videos.';
      });
    }
  }

  Future<void> _remove(KirariReel reel) async {
    if (_removing.contains(reel.id)) return;
    setState(() => _removing.add(reel.id));
    try {
      await context.read<KirariRepository>().action(reel.id, 'unsave');
      if (!mounted) return;
      setState(() => _items = _items.where((item) => item.id != reel.id).toList());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove this saved video.')),
      );
    } finally {
      if (mounted) setState(() => _removing.remove(reel.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: const Text('Saved videos'),
        actions: [
          IconButton(
            tooltip: 'Refresh saved videos',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _items.isEmpty
                  ? const Center(child: Text('Videos you save will appear here.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final reel = _items[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 6),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 64,
                                height: 88,
                                child: reel.coverUrl.isEmpty
                                    ? const ColoredBox(color: Colors.black12)
                                    : Image.network(
                                        reel.coverUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            const ColoredBox(color: Colors.black12),
                                      ),
                              ),
                            ),
                            title: Text(
                              reel.caption.isEmpty ? 'Kirari video' : reel.caption,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '@${reel.creatorUsername.isNotEmpty ? reel.creatorUsername : reel.creatorId}',
                            ),
                            onTap: () => AppNavigation.go(
                              context,
                              PubgetLinks.reelPath(reel.id),
                            ),
                            trailing: IconButton(
                              tooltip: 'Remove from saved videos',
                              onPressed: _removing.contains(reel.id)
                                  ? null
                                  : () => _remove(reel),
                              icon: _removing.contains(reel.id)
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.bookmark_remove_outlined),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
