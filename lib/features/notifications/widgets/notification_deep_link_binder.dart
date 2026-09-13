import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../edits/providers/edit_upload_manager.dart';

/// Routes FCM notification taps into in-app destinations (Edits deep links).
class NotificationDeepLinkBinder extends StatefulWidget {
  const NotificationDeepLinkBinder({
    required this.child,
    this.messaging,
    super.key,
  });

  final Widget child;
  final FirebaseMessaging? messaging;

  @override
  State<NotificationDeepLinkBinder> createState() =>
      _NotificationDeepLinkBinderState();
}

class _NotificationDeepLinkBinderState
    extends State<NotificationDeepLinkBinder> {
  StreamSubscription<RemoteMessage>? _opened;
  var _handledInitial = false;

  @override
  void initState() {
    super.initState();
    final messaging = widget.messaging;
    if (messaging == null) return;
    _opened = FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
    if (!_handledInitial) {
      _handledInitial = true;
      unawaited(
        messaging.getInitialMessage().then((message) {
          if (message != null) _handleMessage(message);
        }),
      );
    }
  }

  void _handleMessage(RemoteMessage message) {
    final destination = message.data['destination'];
    if (destination is! String || destination.trim().isEmpty) return;
    final trimmed = destination.trim();
    final highlight = Uri.tryParse(
      trimmed.startsWith('/') ? 'https://local$trimmed' : trimmed,
    )?.queryParameters['highlight'];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (highlight != null && highlight.isNotEmpty) {
        try {
          context.read<EditUploadManager>().setHighlightEditId(highlight);
        } catch (_) {
          // Provider may be unavailable in early boot / tests.
        }
      }
      unawaited(AppNavigation.go(context, trimmed));
    });
  }

  @override
  void dispose() {
    _opened?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
