import 'dart:async';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/widgets/app_image_loader.dart';
import '../data/sticker_catalog.dart';
import '../data/user_sticker_store.dart';
import '../models/chat_models.dart';
import 'wa_composer/wa_colors.dart';

/// Single-tap sticker sheet: preview, original creator, and save action.
class StickerDetailSheet extends StatefulWidget {
  static Future<void> show(
    BuildContext context, {
    required ChatMessage message,
    required UserStickerStore store,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: WaColors.darkPanel,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StickerDetailSheet(
        message: message,
        store: store,
        onOpenProfile: (uid) {
          Navigator.of(sheetContext).pop();
          AppNavigation.go(context, '/profile?uid=$uid');
        },
      ),
    );
  }

  final ChatMessage message;
  final UserStickerStore store;
  final ValueChanged<String>? onOpenProfile;

  const StickerDetailSheet({
    required this.message,
    required this.store,
    this.onOpenProfile,
    super.key,
  });

  @override
  State<StickerDetailSheet> createState() => _StickerDetailSheetState();
}

class _StickerDetailSheetState extends State<StickerDetailSheet> {
  var _saving = false;
  var _alreadySaved = false;

  ChatMessage get message => widget.message;

  String get creatorId {
    final id = (message.stickerCreatorId ?? '').trim();
    if (id.isNotEmpty) return id;
    if (message.isCatalogSticker) return 'pubget';
    return message.senderId.trim();
  }

  String get creatorName {
    final name = (message.stickerCreatorName ?? '').trim();
    if (name.isNotEmpty) return name;
    if (message.isCatalogSticker) return 'Pubget';
    return message.senderName.trim().isEmpty
        ? 'Pubget user'
        : message.senderName.trim();
  }

  bool get canOpenProfile {
    final id = creatorId;
    return id.isNotEmpty && id != 'pubget' && id != 'system';
  }

  bool get canSave => !message.isCatalogSticker;

  @override
  void initState() {
    super.initState();
    unawaited(_checkSaved());
  }

  Future<void> _checkSaved() async {
    final saved = await widget.store.containsCreatorMedia(
      creatorId: creatorId,
      sourceMediaUrl: message.mediaUrl ?? message.mediaId,
    );
    if (!mounted) return;
    setState(() => _alreadySaved = saved);
  }

  Future<void> _save() async {
    if (!canSave || _saving || _alreadySaved) return;
    setState(() => _saving = true);
    try {
      final bytes = await _loadBytes();
      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ الملصق')),
        );
        return;
      }
      await widget.store.addFromBytes(
        bytes,
        extension: 'png',
        creatorId: creatorId,
        creatorName: creatorName,
        sourceMediaUrl: message.mediaUrl ?? message.mediaId,
      );
      if (!mounted) return;
      setState(() {
        _alreadySaved = true;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الملصق')),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حفظ الملصق')),
      );
    }
  }

  Future<Uint8List?> _loadBytes() async {
    final url = (message.mediaUrl ?? message.thumbnailUrl ?? '').trim();
    if (url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return null;
        }
        return await consolidateHttpClientResponseBytes(response);
      } finally {
        client.close(force: true);
      }
    }
    return FirebaseStorage.instance.ref(url).getData(12 * 1024 * 1024);
  }

  void _openCreatorProfile() {
    if (!canOpenProfile) return;
    final open = widget.onOpenProfile;
    if (open != null) {
      open(creatorId);
      return;
    }
    AppNavigation.go(context, '/profile?uid=$creatorId');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: WaColors.handle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 180,
              height: 180,
              child: message.isCatalogSticker
                  ? StickerMark(
                      stickerKey: message.stickerKey ?? '',
                      size: 180,
                    )
                  : ((message.mediaUrl ?? message.thumbnailUrl ?? '')
                          .trim()
                          .isEmpty
                      ? const ColoredBox(
                          color: WaColors.darkPill,
                          child: Icon(
                            Icons.sticky_note_2_outlined,
                            color: WaColors.iconMuted,
                            size: 64,
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AppImageLoader(
                            imageUrl:
                                message.mediaUrl ?? message.thumbnailUrl ?? '',
                            fit: BoxFit.contain,
                          ),
                        )),
            ),
            const SizedBox(height: 16),
            TextButton(
              key: const Key('sticker-creator-name'),
              onPressed: canOpenProfile ? _openCreatorProfile : null,
              style: TextButton.styleFrom(
                foregroundColor: WaColors.textPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: Text(
                creatorName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: canOpenProfile
                      ? WaColors.cursorGreen
                      : WaColors.textPrimary,
                  decoration: canOpenProfile
                      ? TextDecoration.underline
                      : TextDecoration.none,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'منشئ الملصق',
              style: TextStyle(color: WaColors.iconMuted, fontSize: 12),
            ),
            const SizedBox(height: 20),
            if (canSave)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  key: const Key('sticker-detail-save'),
                  onPressed: (_saving || _alreadySaved) ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: WaColors.cursorGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: WaColors.segmentActive,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _alreadySaved ? 'تم الحفظ' : 'حفظ الملصق',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}