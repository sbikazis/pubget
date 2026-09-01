import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_contrast_theme.dart';

class ChatBackgroundPickerPage extends StatelessWidget {
  const ChatBackgroundPickerPage({required this.current, super.key});

  final String? current;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat background')),
      body: GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: 0.82,
        ),
        itemCount: pubgetChatBackgrounds.length,
        itemBuilder: (context, index) {
          final option = pubgetChatBackgrounds[index];
          final selected = option.$1 == current;
          return Semantics(
            selected: selected,
            button: true,
            label: option.$2,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              onTap: () async {
                final result = await context
                    .read<ChatProvider>()
                    .updateBackground(option.$1);
                if (result.isSuccess && context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: option.$3),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: selected
                        ? Theme.of(context).colorScheme.secondary
                        : Colors.white54,
                    width: selected ? 4 : 1,
                  ),
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(AppRadius.lg),
                      ),
                    ),
                    child: Text(
                      option.$2,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
