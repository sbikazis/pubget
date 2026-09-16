import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../models/fan_work_lifecycle.dart';
import '../models/fan_work_models.dart';
import '../repositories/fan_work_repository.dart';
import '../widgets/fan_work_widgets.dart';

/// Full list of one creator's published Fan Works, opened from the profile.
class ProfileFanWorksPage extends StatefulWidget {
  const ProfileFanWorksPage({this.userId, super.key});

  final String? userId;

  @override
  State<ProfileFanWorksPage> createState() => _ProfileFanWorksPageState();
}

class _ProfileFanWorksPageState extends State<ProfileFanWorksPage> {
  final _scroll = ScrollController();
  final _items = <FanWork>[];
  FanWork? _cursor;
  var _hasMore = true;
  var _loading = false;
  var _loaded = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    Future<void>.microtask(_loadMore);
  }

  @override
  void dispose() {
    _scroll.removeListener(_maybeLoadMore);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore || _failure != null) return;
    final uid = widget.userId ?? '';
    if (uid.isEmpty) return;
    FanWorkRepository repository;
    try {
      repository = context.read<FanWorkRepository>();
    } on ProviderNotFoundException {
      setState(() {
        _loaded = true;
        _hasMore = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failure = null;
    });
    final result = await repository.getCreatorWorks(
      creatorId: uid,
      after: _cursor,
      limit: 12,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _loaded = true;
      final failure = result.failureOrNull;
      if (failure != null) {
        _failure = failure.message;
        return;
      }
      final page = result.valueOrNull;
      if (page != null) {
        _items.addAll(page.items);
        _cursor = page.cursor;
        _hasMore = page.hasMore;
      }
    });
  }

  void _maybeLoadMore() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < 400) unawaited(_loadMore());
  }

  void _retry() {
    setState(() {
      _failure = null;
      _loaded = false;
    });
    unawaited(_loadMore());
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    final isOwner = currentUserId != null && currentUserId == widget.userId;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(FanWorkStrings.feedTitle),
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (_failure != null) {
              return PubgetErrorState(
                message: 'Could not load fan works.',
                onRetry: _retry,
              );
            }
            if (!_loaded && _items.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_loaded && _items.isEmpty) {
              return PubgetEmptyState(
                icon: Icons.brush_outlined,
                title: isOwner ? 'No fan works yet' : 'No fan works to show',
                message: isOwner
                    ? 'Share a drawing, manga page, or story.'
                    : 'This creator has not shared works yet.',
              );
            }
            return GridView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(AppSpacing.sm),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: 0.62,
              ),
              itemCount: _items.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _items.length) {
                  return const Center(child: CircularProgressIndicator());
                }
                return FanWorkPreviewCard(work: _items[index]);
              },
            );
          },
        ),
      ),
    );
  }
}