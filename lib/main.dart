// Flutter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';

// Google Mobile Ads
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة Firebase
  await Firebase.initializeApp(
    options: const FirebaseOptions(
    apiKey: 'AIzaSyDPgjnaviwqxz8lGK_o9pjg4zuoB7RrVBw',
    appId: '1:193460577475:android:2ddc9727c0ca84dbb86e76',
    messagingSenderId: '193460577475',
    projectId: 'pubget-817cf',
       )
  );

  // تهيئة Google Mobile Ads
  await MobileAds.instance.initialize();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const PubgetApp());
}