import 'dart:io';
import 'dart:typed_data';

import '../models/edit_models.dart';

Future<(int, Stream<List<int>>)> prepareEditR2UploadSource(
  EditUploadSource source,
) async {
  final path = source.path;
  if (path != null && path.isNotEmpty) {
    final file = File(path);
    return (await file.length(), file.openRead());
  }
  final bytes = Uint8List.fromList(source.bytes ?? const <int>[]);
  return (bytes.length, Stream<List<int>>.value(bytes));
}
