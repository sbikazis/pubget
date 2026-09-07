import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/links/pubget_links.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../l10n/group_copy.dart';

abstract final class GroupCreateSuccessSheet {
  static Future<void> show(
    BuildContext context, {
    required String groupId,
    required String groupName,
  }) {
    final copy = GroupCopy.of(context);
    final strings = AppStrings.of(context);
    final url = PubgetLinks.group(groupId);
    return PubgetBottomSheet.show<void>(
      context,
      title: copy.created,
      isScrollControlled: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SelectableText(url, key: const Key('group-create-deep-link')),
          const SizedBox(height: AppSpacing.lg),
          PubgetPrimaryButton(
            key: const Key('group-create-copy-link'),
            onPressed: () => PubgetLinks.copy(
              context,
              url,
              type: 'group',
              message: strings.copyLink,
            ),
            semanticLabel: copy.copyLink,
            child: Text(copy.copyLink),
          ),
          const SizedBox(height: AppSpacing.sm),
          PubgetSecondaryButton(
            key: const Key('group-create-share-in-app'),
            onPressed: () {
              Navigator.pop(context);
              AppNavigation.go(context, '/private');
            },
            semanticLabel: copy.shareInApp,
            child: Text(copy.shareInApp),
          ),
          const SizedBox(height: AppSpacing.sm),
          PubgetSecondaryButton(
            key: const Key('group-create-share-native'),
            onPressed: () => PubgetLinks.share(
              context,
              url: url,
              title: groupName,
              type: 'group',
            ),
            semanticLabel: copy.shareOutside,
            child: Text(copy.shareOutside),
          ),
          const SizedBox(height: AppSpacing.sm),
          PubgetTextButton(
            key: const Key('group-create-skip'),
            onPressed: () => Navigator.pop(context),
            semanticLabel: copy.skip,
            child: Text(copy.skip),
          ),
        ],
      ),
    );
  }
}
