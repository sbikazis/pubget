import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:url_launcher/url_launcher.dart';

class ForceUpdateService {
  static Future<void> check(BuildContext context) async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        // في التطوير خليها صفر، في الإنتاج ساعة
        minimumFetchInterval: const Duration(seconds : 0),
      ));
      await rc.fetchAndActivate();

      final info = await PackageInfo.fromPlatform();
      final current = Version.parse(info.version);

      // أندرويد فقط
      final minStr = rc.getString('min_version_android');
      final url = rc.getString('update_url_android');

      if (minStr.isEmpty) return;

      final minVersion = Version.parse(minStr);

      if (current < minVersion && context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => ForceUpdatePage(url: url)),
          (_) => false,
        );
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
  }
}

class ForceUpdatePage extends StatelessWidget {
  final String url;
  const ForceUpdatePage({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PopScope(
        canPop: false, // ممنوع الرجوع
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.system_update_rounded, size: 90, color: Colors.white),
                const SizedBox(height: 24),
                const Text('تحديث مطلوب',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text('يجب تحديث Pubget للمتابعة. الإصدار الحالي غير مدعوم.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 15)),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => launchUrl(
                      Uri.parse(url),
                      mode: LaunchMode.externalApplication,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7B2CBF),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('تحديث الآن', style: TextStyle(fontSize: 17, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}