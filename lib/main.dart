// Flutter
import 'package:flutter/material.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };

  runApp(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text("APP STARTED"),
        ),
      ),
    ),
  );
}