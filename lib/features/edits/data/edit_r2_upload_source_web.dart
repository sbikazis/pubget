import 'dart:typed_data';

import '../models/edit_models.dart';

Future<(int, Stream<List<int>>)> prepareEditR2UploadSource(
  EditUploadSource source,
) async {
  // Browser file pickers provide bytes; browser paths are opaque and cannot
  // be opened with dart:io.
  final bytes = Uint8List.fromList(source.bytes ?? const <int>[]);
  if (bytes.isEmpty) {
    throw ArgumentError('Browser upload bytes are unavailable.');
  }
  return (bytes.length, Stream<List<int>>.value(bytes));
}
