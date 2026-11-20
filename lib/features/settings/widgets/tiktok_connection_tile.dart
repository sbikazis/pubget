import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';

class TikTokConnectionTile extends StatefulWidget {
  const TikTokConnectionTile({super.key});

  @override
  State<TikTokConnectionTile> createState() => _TikTokConnectionTileState();
}

class _TikTokConnectionTileState extends State<TikTokConnectionTile>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _working = false;
  bool _connected = false;
  bool _needsReconnect = false;
  String? _displayName;
  String? _failure;

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'us-central1');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final result = await _functions
          .httpsCallable('getTikTokConnectionStatus')
          .call<Map<dynamic, dynamic>>();
      if (!mounted) return;
      setState(() {
        _connected = result.data['connected'] == true;
        _needsReconnect = result.data['needsReconnect'] == true;
        _displayName = result.data['displayName'] as String?;
        _failure = null;
        _loading = false;
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _failure = error.message ?? error.code;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failure = AppStrings.of(context).pick(
          'Could not load TikTok connection status.',
          'تعذّر تحميل حالة ربط TikTok.',
        );
        _loading = false;
      });
    }
  }

  Future<void> _connect() async {
    setState(() {
      _working = true;
      _failure = null;
    });
    try {
      final result = await _functions
          .httpsCallable('beginTikTokOAuth')
          .call<Map<dynamic, dynamic>>();
      final rawUrl = result.data['authorizationUrl'] as String?;
      final uri = rawUrl == null ? null : Uri.tryParse(rawUrl);
      if (uri == null || uri.scheme != 'https' ||
          uri.host != 'www.tiktok.com') {
        throw StateError('The TikTok authorization URL is invalid.');
      }
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) throw StateError('Could not open TikTok authorization.');
    } catch (error) {
      if (mounted) {
        setState(() => _failure = AppStrings.of(context).pick(
          'Could not start TikTok authorization. Please try again.',
          'تعذّر بدء تفويض TikTok. حاول مرة أخرى.',
        ));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _disconnect() async {
    setState(() {
      _working = true;
      _failure = null;
    });
    try {
      await _functions.httpsCallable('disconnectTikTok').call();
      if (!mounted) return;
      setState(() {
        _connected = false;
        _needsReconnect = false;
        _displayName = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _failure = AppStrings.of(context).pick(
          'Could not disconnect TikTok. Please try again.',
          'تعذّر فصل TikTok. حاول مرة أخرى.',
        ));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final title = copy.pick('TikTok account', 'حساب TikTok');
    final status = _loading
        ? copy.pick('Checking connection…', 'جارٍ التحقق من الربط…')
        : _connected
            ? copy.pick('Connected', 'متصل') +
                (_displayName == null ? '' : ' · $_displayName') +
                (_needsReconnect
                    ? copy.pick(' · Reconnect required', ' · يلزم إعادة الربط')
                    : '')
            : copy.pick('Not connected', 'غير متصل');

    return PubgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.music_video_outlined),
            title: Text(title),
            subtitle: Text(status),
          ),
          if (_failure != null) ...[
            Text(_failure!, style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            )),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (_loading)
            const LinearProgressIndicator()
          else if (_connected)
            Row(
              children: [
                Expanded(
                  child: PubgetTextButton(
                    onPressed: _working ? null : _loadStatus,
                    semanticLabel: copy.pick('Refresh TikTok status', 'تحديث حالة TikTok'),
                    child: Text(copy.pick('Refresh status', 'تحديث الحالة')),
                  ),
                ),
                if (_needsReconnect)
                  Expanded(
                    child: PubgetTextButton(
                      onPressed: _working ? null : _connect,
                      semanticLabel: copy.pick('Reconnect TikTok', 'إعادة ربط TikTok'),
                      child: Text(copy.pick('Reconnect', 'إعادة الربط')),
                    ),
                  ),
                Expanded(
                  child: PubgetTextButton(
                    onPressed: _working ? null : _disconnect,
                    semanticLabel: copy.pick('Disconnect TikTok', 'فصل TikTok'),
                    child: Text(copy.pick('Disconnect', 'فصل الحساب')),
                  ),
                ),
              ],
            )
          else
            PubgetPrimaryButton(
              onPressed: _working ? null : _connect,
              semanticLabel: copy.pick('Connect TikTok account', 'ربط حساب TikTok'),
              loading: _working,
              child: Text(copy.pick('Connect TikTok', 'ربط TikTok')),
            ),
        ],
      ),
    );
  }
}
