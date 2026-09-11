import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../games/models/game_type_registry.dart';
import '../models/chat_models.dart';
import 'chat_contrast_theme.dart';

const _gameAccent = Color(0xFF6C5CE7);
const _waGreen = Color(0xFF00A884);

/// Interactive game lobby / invitation card (max bubble width).
class ChatGameLobbyCard extends StatelessWidget {
  const ChatGameLobbyCard({
    required this.message,
    required this.contrast,
    this.onJoin,
    super.key,
  });

  final ChatMessage message;
  final ChatContrastTheme contrast;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    final activity = message.gameActivity;
    final spec = activity == null
        ? null
        : GameTypeRegistry.byName(activity.gameType);
    final title = activity?.title?.trim().isNotEmpty == true
        ? activity!.title!
        : (spec?.name ?? 'Game');
    final host = activity?.hostName?.trim().isNotEmpty == true
        ? activity!.hostName!
        : message.senderName;
    final current = activity?.playerCount ?? 1;
    final max = activity?.maxPlayers ?? (spec?.capabilities.maxPlayers ?? 8);
    final status = activity?.isStarted == true
        ? 'مباشر الآن'
        : activity?.isFull == true
            ? 'اكتمل العدد'
            : 'قاعة الانتظار';
    final cta = activity?.isStarted == true
        ? 'عرض اللعبة'
        : activity?.isFull == true
            ? 'اكتمل العدد'
            : 'انضمام للعبة';
    final avatars = activity?.participantAvatars ?? const <String>[];
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        child: Container(
          key: ValueKey<String>('message-${message.id}'),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF202C33) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _gameAccent, width: 1.2),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(11),
                ),
                child: SizedBox(
                  height: 96,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              _gameAccent.withValues(alpha: 0.95),
                              const Color(0xFF2D1B69),
                            ],
                          ),
                        ),
                      ),
                      Center(
                        child: Icon(
                          spec?.icon ?? Icons.sports_esports,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: activity?.isStarted == true
                                ? const Color(0xFFE53935)
                                : _waGreen,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            status,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: dark ? Colors.white : const Color(0xFF111B21),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'بدأ $host غرفة لعب جديدة',
                      style: TextStyle(
                        fontSize: 13,
                        color: dark
                            ? const Color(0xFFD1D7DB)
                            : const Color(0xFF54656F),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (current / max).clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: dark
                                  ? const Color(0xFF2A3942)
                                  : const Color(0xFFE9EDEF),
                              color: _gameAccent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$current/$max',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8696A0),
                          ),
                        ),
                      ],
                    ),
                    if (avatars.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 28,
                        child: Stack(
                          children: <Widget>[
                            for (var i = 0; i < avatars.take(5).length; i++)
                              Positioned(
                                left: i * 18.0,
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: _gameAccent,
                                  backgroundImage: avatars[i].startsWith('http')
                                      ? NetworkImage(avatars[i])
                                      : null,
                                  child: avatars[i].startsWith('http')
                                      ? null
                                      : Text(
                                          avatars[i].isEmpty
                                              ? '?'
                                              : avatars[i][0].toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0x338696A0)),
              InkWell(
                onTap: activity?.isFull == true && activity?.isStarted != true
                    ? null
                    : onJoin,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  child: Text(
                    cta,
                    style: TextStyle(
                      color: activity?.isFull == true &&
                              activity?.isStarted != true
                          ? const Color(0xFF8696A0)
                          : _waGreen,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rich new-member welcome card (center aligned).
class ChatNewMemberCard extends StatelessWidget {
  const ChatNewMemberCard({
    required this.message,
    required this.contrast,
    this.onWelcome,
    this.onPrivateChat,
    super.key,
  });

  final ChatMessage message;
  final ChatContrastTheme contrast;
  final VoidCallback? onWelcome;
  final VoidCallback? onPrivateChat;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final meta = message.cardMeta ?? const <String, dynamic>{};
    final title = message.senderTitle ??
        (meta['title'] as String?) ??
        (meta['bio'] as String?) ??
        '';
    final ageCountry = [
      if (meta['age'] != null) '${meta['age']} سنة',
      if ((meta['country'] as String?)?.trim().isNotEmpty == true)
        meta['country'],
    ].join(' • ');
    final badges = (meta['badges'] is List)
        ? (meta['badges'] as List).whereType<String>().toList()
        : const <String>['عضو جديد'];
    final bio = (meta['bio'] as String?) ?? message.text ?? '';

    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.86,
        ),
        child: Container(
          key: ValueKey<String>('message-${message.id}'),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const <Color>[Color(0xCC2A1B4A), Color(0xCC111B21)]
                  : const <Color>[Color(0xE6E9D9FF), Color(0xE6FFFFFF)],
            ),
            border: Border.all(
              color: const Color(0xFF6C3FC5).withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _waGreen.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'رحّبوا بالعضو الجديد!',
                  style: TextStyle(
                    color: _waGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: <Color>[Color(0xFF6C3FC5), Color(0xFF00A884)],
                  ),
                ),
                child: PubgetAvatar(
                  imageUrl: message.senderAvatar,
                  name: message.senderName,
                  size: PubgetAvatarSize.large,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message.senderName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: dark ? Colors.white : const Color(0xFF111B21),
                ),
              ),
              if (title.isNotEmpty)
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8696A0),
                  ),
                ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  if (ageCountry.isNotEmpty)
                    _InfoChip(label: ageCountry, dark: dark),
                  for (final badge in badges.take(3))
                    _InfoChip(label: badge, dark: dark),
                ],
              ),
              if (bio.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  bio,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: dark
                        ? const Color(0xFFD1D7DB)
                        : const Color(0xFF54656F),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: onWelcome,
                      child: const Text('👋 ترحيب'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _waGreen,
                      ),
                      onPressed: onPrivateChat ??
                          () {
                            final uid = message.senderId.trim();
                            if (uid.isEmpty) return;
                            AppNavigation.go(context, '/profile?uid=$uid');
                          },
                      child: const Text('💬 دردشة'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.dark});

  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: dark ? const Color(0xFFD1D7DB) : const Color(0xFF54656F),
        ),
      ),
    );
  }
}

/// Live event / RSVP card.
class ChatEventCard extends StatelessWidget {
  const ChatEventCard({
    required this.message,
    required this.contrast,
    this.onOpen,
    super.key,
  });

  final ChatMessage message;
  final ChatContrastTheme contrast;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final meta = message.cardMeta ?? const <String, dynamic>{};
    final title = (meta['title'] as String?) ?? message.text ?? 'فعالية';
    final when = (meta['when'] as String?) ?? (meta['schedule'] as String?) ?? '';
    final place = (meta['place'] as String?) ?? (meta['location'] as String?) ?? '';

    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        child: Material(
          color: dark ? const Color(0xFF202C33) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            key: ValueKey<String>('message-${message.id}'),
            onTap: onOpen,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.event, color: Color(0xFFFF8C00)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: dark ? Colors.white : const Color(0xFF111B21),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (when.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF8C00).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        when,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFF8C00),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  if (place.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      place,
                      style: const TextStyle(
                        color: Color(0xFF8696A0),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: const <Widget>[
                      _RsvpChip(label: 'سأحضر ✅'),
                      SizedBox(width: 6),
                      _RsvpChip(label: 'ربما ❓'),
                      SizedBox(width: 6),
                      _RsvpChip(label: 'لن أحضر ❌'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RsvpChip extends StatelessWidget {
  const _RsvpChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x148696A0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Debate / theory card with consensus meter.
class ChatDebateCard extends StatelessWidget {
  const ChatDebateCard({
    required this.message,
    required this.contrast,
    this.onReply,
    super.key,
  });

  final ChatMessage message;
  final ChatContrastTheme contrast;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final meta = message.cardMeta ?? const <String, dynamic>{};
    final agree = ((meta['agree'] as num?)?.toDouble() ?? 0.7).clamp(0.0, 1.0);
    final theory = (meta['theory'] as String?) ?? message.text ?? '';

    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        child: Container(
          key: ValueKey<String>('message-${message.id}'),
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF202C33) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: const Border(
              left: BorderSide(color: Color(0xFFD8A838), width: 4),
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.push_pin, color: Color(0xFFD8A838), size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${message.senderName} · ${message.senderRole}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFFD8A838),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  theory,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: dark ? Colors.white : const Color(0xFF111B21),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      flex: (agree * 100).round().clamp(1, 99),
                      child: Container(
                        height: 10,
                        color: _waGreen,
                      ),
                    ),
                    Expanded(
                      flex: ((1 - agree) * 100).round().clamp(1, 99),
                      child: Container(
                        height: 10,
                        color: const Color(0xFFE53935),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'موافق ${(agree * 100).round()}% · غير موافق ${((1 - agree) * 100).round()}%',
                style: const TextStyle(fontSize: 11, color: Color(0xFF8696A0)),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: onReply,
                  child: const Text('أضف حجتك / رأيك'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatDateDivider extends StatelessWidget {
  const ChatDateDivider({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: dark
              ? const Color(0x99202C33)
              : const Color(0xE6E9EDEF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: dark ? Colors.white70 : const Color(0xFF54656F),
          ),
        ),
      ),
    );
  }
}

class ChatEncryptionBanner extends StatelessWidget {
  const ChatEncryptionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 8, 24, 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0x33F2C94C),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'الرسائل والمكالمات محمية بتشفير بين الطرفين. لا يمكن لأحد خارج هذه المحادثة قراءتها أو الاستماع إليها، ولا حتى Pubget.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            height: 1.35,
            color: Color(0xFFE6C35C),
          ),
        ),
      ),
    );
  }
}

String chatDayLabel(DateTime? date, {required DateTime now}) {
  if (date == null) return '';
  final local = date.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'اليوم';
  if (diff == 1) return 'أمس';
  const months = <String>[
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}
