import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'wa_colors.dart';

class WaMediaPreviewPage extends StatefulWidget {
  const WaMediaPreviewPage({
    required this.bytes,
    required this.fileName,
    required this.contentType,
    required this.isVideo,
    super.key,
  });

  final Uint8List bytes;
  final String fileName;
  final String contentType;
  final bool isVideo;

  static Future<bool?> open(
    BuildContext context, {
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required bool isVideo,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => WaMediaPreviewPage(
          bytes: bytes,
          fileName: fileName,
          contentType: contentType,
          isVideo: isVideo,
        ),
      ),
    );
  }

  @override
  State<WaMediaPreviewPage> createState() => _WaMediaPreviewPageState();
}

class _WaMediaPreviewPageState extends State<WaMediaPreviewPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        leading: IconButton(
          key: const Key('app-back'),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const BackButtonIcon(),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Center(
              child: widget.isVideo
                  ? const Icon(Icons.videocam, color: Colors.white54, size: 72)
                  : Image.memory(widget.bytes, fit: BoxFit.contain),
            ),
          ),
          SafeArea(
            top: false,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Material(
                  color: WaColors.cursorGreen,
                  shape: const CircleBorder(),
                  child: InkWell(
                    key: const Key('media-preview-send'),
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.pop(context, true),
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(Icons.send_rounded, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
