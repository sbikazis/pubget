import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/widgets/pubget_design_system.dart';
import '../../../l10n/group_copy.dart';
import '../../../models/group_models.dart';

class Step6Preview extends StatelessWidget {
  const Step6Preview({
    required this.name,
    required this.description,
    required this.type,
    required this.animeId,
    required this.animeTitle,
    required this.joinPolicy,
    required this.maxMembers,
    required this.rules,
    required this.welcomeMessage,
    required this.chatBackgroundUrl,
    required this.imageUrl,
    required this.coverUrl,
    required this.character,
    super.key,
  });

  final String name;
  final String description;
  final GroupType? type;
  final String? animeId;
  final String? animeTitle;
  final JoinPolicy joinPolicy;
  final int maxMembers;
  final String rules;
  final String? welcomeMessage;
  final String? chatBackgroundUrl;
  final String imageUrl;
  final String coverUrl;
  final RoleplayCharacter? character;

  @override
  Widget build(BuildContext context) {
    final copy = GroupCopy.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            copy.previewTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            copy.previewHint,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _PreviewCard(
            name: name,
            namePlaceholder: copy.groupNamePlaceholder,
            imageUrl: imageUrl,
            coverUrl: coverUrl,
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionCard(
            title: copy.basicInfo,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _PreviewRow(label: copy.name, value: name),
                _PreviewRow(label: copy.description, value: description.isEmpty ? '—' : description),
                if (type != null)
                  _PreviewRow(label: copy.typeLabelPreview, value: copy.typeLabel(type!)),
                if (type == GroupType.animeRoleplay && animeTitle != null)
                  _PreviewRow(label: copy.anime, value: animeTitle!),
                _PreviewRow(label: copy.maxMembersLabelPreview, value: maxMembers.toString()),
                _PreviewRow(label: copy.joinPolicyLabelTitle, value: copy.joinPolicyLabelValue(joinPolicy.name)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionCard(
            title: copy.welcomeMessageSection,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (welcomeMessage != null && welcomeMessage!.isNotEmpty)
                  Text(
                    welcomeMessage!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                        ),
                  )
                else
                  Text(
                    copy.noWelcomeMessage,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white54,
                        ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (rules.isNotEmpty) ...[
            _SectionCard(
              title: copy.rules,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final rule in rules.split('\n'))
                    if (rule.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• ${rule.trim()}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                              ),
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (character != null) ...[
            _SectionCard(
              title: copy.roleplayCharacterSection,
              child: Row(
                children: <Widget>[
                  PubgetAvatar(
                    imageUrl: character!.avatarUrl,
                    name: character!.name,
                    size: PubgetAvatarSize.medium,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          character!.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Text(
                          copy.reservedForFounder,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white54,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.name,
    required this.namePlaceholder,
    required this.imageUrl,
    required this.coverUrl,
  });

  final String name;
  final String namePlaceholder;
  final String imageUrl;
  final String coverUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const ColoredBox(color: Color(0xFF0B0714)),
            if (coverUrl.trim().isNotEmpty)
              AppImageLoader(imageUrl: coverUrl.trim(), fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0x00140C22), Color(0xCC140C22)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  PubgetAvatar(
                    imageUrl: imageUrl.trim().isEmpty ? null : imageUrl.trim(),
                    name: name,
                    size: PubgetAvatarSize.large,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      name.isEmpty ? namePlaceholder : name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.royalPurple.withValues(alpha: 0.35),
            const Color(0xFF160B24),
          ],
        ),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}