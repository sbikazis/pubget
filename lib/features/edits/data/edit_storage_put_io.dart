import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../models/edit_models.dart';

UploadTask putEditVideo(
  Reference ref,
  EditUploadSource source,
  SettableMetadata metadata,
) {
  final path = source.path;
  if (path != null && path.isNotEmpty) {
    return ref.putFile(File(path), metadata);
  }
  return ref.putData(
    Uint8List.fromList(source.bytes ?? const <int>[]),
    metadata,
  );
}
