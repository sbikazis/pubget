import '../models/edit_models.dart';
import 'edit_r2_upload_source_io.dart'
    if (dart.library.html) 'edit_r2_upload_source_web.dart' as impl;

Future<(int, Stream<List<int>>)> prepareEditR2UploadSource(
  EditUploadSource source,
) => impl.prepareEditR2UploadSource(source);
