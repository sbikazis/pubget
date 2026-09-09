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
  final _caption = TextEditingController();

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(onPressed: () {}, icon: const Icon(Icons.crop)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.text_fields)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.edit)),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Center(
              child: widget.isVideo
                  ? const Icon(
                      Icons.videocam,
                      color: Colors.white54,
                      size: 72,
                    )
                  : Image.memory(widget.bytes, fit: BoxFit.contain),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: WaColors.darkPill,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      alignment: Alignment.centerRight,
                      child: TextField(
                        controller: _caption,
                        style: const TextStyle(color: WaColors.textPrimary),
                        cursorColor: WaColors.cursorGreen,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'مراسلة',
                          hintStyle: TextStyle(color: WaColors.iconMuted),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: WaColors.cursorGreen,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.pop(context, true),
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.send_rounded, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
