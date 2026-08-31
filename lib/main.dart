import 'package:flutter/widgets.dart';

import 'app/firebase_bootstrap.dart';
import 'app/pubget_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseState = await FirebaseBootstrap.initialize();
  runApp(PubgetApp(firebaseState: firebaseState));
}
