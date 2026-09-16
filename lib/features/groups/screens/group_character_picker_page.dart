import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../core/errors/failure.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../anime/models/anime_models.dart';
import '../../anime/providers/anime_hub_social_provider.dart';
import '../../anime/repositories/anime_repository.dart';
import '../data/group_fuzzy.dart';
import '../l10n/group_copy.dart';
import '../models/group_models.dart';

class GroupCharacterPickerPage extends StatefulWidget {
  const GroupCharacterPickerPage({
    this.animeId,
    this.reservedKeys = const <String>{},
    this.catalog,
    super.key,
  });

  final String? animeId;
  final Set<String> reservedKeys;
  final List<RoleplayCharacter>? catalog;

  @override
  State<GroupCharacterPickerPage> createState() =>
      _GroupCharacterPickerPageState();
}

class _GroupCharacterPickerPageState extends State<GroupCharacterPickerPage> {
  final _search = TextEditingController();
  List<RoleplayCharacter> _items = const <RoleplayCharacter>[];
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _state = LoadingState.loading;
      _failure = null;
    });
    if (widget.catalog != null) {
      _apply(widget.catalog!);
      return;
    }
    if (widget.animeId != null && widget.animeId!.trim().isNotEmpty) {
      try {
        final repo = context.read<AnimeRepository>();
        final result = await repo.getCharacters(widget.animeId!);
        if (!mounted) return;
        result.fold(onSuccess: _fromAnime, onFailure: _fail);
        return;
      } on ProviderNotFoundException {
        _fail(const UnknownError('Anime catalog is unavailable.'));
        return;
      }
    }
    try {
      final social = context.read<AnimeHubSocialProvider>();
      await social.loadPopularCharacters();
      if (!mounted) return;
      _apply(
        social.popularCharacters
            .map(
              (item) => RoleplayCharacter(
                key: item.characterId,
                name: item.name,
                avatarUrl: item.imageUrl ?? '',
              ),
            )
            .toList(growable: false),
      );
      if (social.popularCharactersState == LoadingState.error) {
        _fail(
          social.popularCharactersFailure ??
              const UnknownError('Characters could not load.'),
        );
      }
    } on ProviderNotFoundException {
      _fail(const UnknownError('Character catalog is unavailable.'));
    }
  }

  void _fromAnime(List<AnimeCharacter> characters) {
    _apply(
      characters
          .map(
            (item) => RoleplayCharacter(
              key: item.id,
              name: item.name,
              avatarUrl: item.imageUrl ?? '',
            ),
          )
          .toList(growable: false),
    );
  }

  void _apply(List<RoleplayCharacter> items) {
    final reserved = widget.reservedKeys;
    setState(() {
      _items = items
          .map(
            (item) => reserved.contains(item.key) ? item.asReserved() : item,
          )
          .toList(growable: false);
      _state = _items.isEmpty ? LoadingState.empty : LoadingState.loaded;
      _failure = null;
    });
  }

  void _fail(Failure failure) {
    setState(() {
      _failure = failure;
      _state = failure is NetworkError
          ? LoadingState.offline
          : LoadingState.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final copy = GroupCopy.of(context);
    final visible = _items
        .where((item) => GroupFuzzy.matches(_search.text, item.name))
        .toList(growable: false);
    final empty = _state == LoadingState.loaded && visible.isEmpty;
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(copy.selectCharacter),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: <Widget>[
            PubgetSearchField(
              key: const Key('group-character-search'),
              controller: _search,
              hint: copy.searchCharacters,
              onChanged: (_) => setState(() {}),
              onClear: () {
                _search.clear();
                setState(() {});
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: PubgetLoadingStateView(
                state: empty ? LoadingState.empty : _state,
                onRetry: _load,
                empty: PubgetEmptyState(
                  key: const Key('group-character-empty'),
                  title: copy.noCharacters,
                  message: copy.noCharactersHint,
                  icon: Icons.person_off_outlined,
                ),
                error: PubgetErrorState(
                  message: _failure?.message ?? copy.noCharacters,
                  onRetry: _load,
                ),
                offline: PubgetOfflineState(onRetry: _load),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final character = visible[index];
                    return _CharacterTile(
                      character: character,
                      onTap: () => _select(character),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _select(RoleplayCharacter character) {
    final copy = GroupCopy.of(context);
    if (character.reserved) {
      PubgetSnackbars.showInfo(context, copy.characterReserved);
      return;
    }
    Navigator.pop(context, character);
  }
}

class _CharacterTile extends StatelessWidget {
  const _CharacterTile({required this.character, required this.onTap});

  final RoleplayCharacter character;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PubgetCard(
      key: Key('group-character-${character.key}'),
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Column(
            children: <Widget>[
              Expanded(
                child: character.avatarUrl.isEmpty
                    ? const ColoredBox(
                        color: Color(0x332C1654),
                        child: Center(child: Icon(Icons.person_outline)),
                      )
                    : AppImageLoader(
                        imageUrl: character.avatarUrl,
                        fit: BoxFit.cover,
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Text(
                  character.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          if (character.reserved)
            const DecoratedBox(
              decoration: BoxDecoration(color: Color(0x99210F2E)),
              child: Center(
                child: Icon(Icons.lock_outline, color: Colors.white70, size: 32),
              ),
            ),
        ],
      ),
    );
  }
}
