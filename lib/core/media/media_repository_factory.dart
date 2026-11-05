import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'default_media_repository.dart';
import 'firestore_media_metadata_store.dart';
import 'in_memory_media_metadata_store.dart';
import 'media_compressor.dart';
import 'media_repository.dart';
import 'media_storage_provider.dart';
import 'media_upload_service.dart';
import 'memory_media_storage_provider.dart';
import 'r2_media_storage_provider.dart';
import 'unavailable_media_repository.dart';

/// Shared production provider used by chat and other feature-specific media
/// flows that need a conversation-scoped R2 object key.
R2MediaStorageProvider createR2MediaStorageProvider({
  FirebaseAuth? auth,
  String? workerUrlOverride,
}) {
  final config = resolveMediaBackendConfig(workerUrlOverride: workerUrlOverride);
  if (!config.isConfigured) {
    throw StateError('Cloudflare media storage is not configured.');
  }
  final firebaseAuth = auth ?? FirebaseAuth.instance;
  return R2MediaStorageProvider(
    workerUrl: config.workerUrl,
    idTokenProvider: () async => await firebaseAuth.currentUser?.getIdToken(),
  );
}

/// Builds the app-wide media repository. Firebase remains the identity and
/// metadata layer; Cloudflare R2 is the only production destination for bytes.
MediaRepository createMediaRepository({
  FirebaseAuth? auth,
  FirebaseFirestore? firestore,
  String? backendOverride,
  String? workerUrlOverride,
}) {
  final config = resolveMediaBackendConfig(
    backendOverride: backendOverride,
    workerUrlOverride: workerUrlOverride,
  );

  if (config.backend == MediaBackend.memory) {
    final storage = MemoryMediaStorageProvider();
    final upload = MediaUploadService(
      provider: storage,
      compressor: const DefaultMediaCompressor(),
    );
    return DefaultMediaRepository(
      uploadService: upload,
      store: InMemoryMediaMetadataStore(),
      provider: storage,
    );
  }

  if (!config.isConfigured) {
    return const UnavailableMediaRepository(
      'Cloudflare media storage is not configured. Please try again later.',
    );
  }

  final storage = createR2MediaStorageProvider(auth: auth, workerUrlOverride: workerUrlOverride);
  final upload = MediaUploadService(
    provider: storage,
    compressor: const DefaultMediaCompressor(),
  );
  return DefaultMediaRepository(
    uploadService: upload,
    store: FirestoreMediaMetadataStore(firestore: firestore),
    provider: storage,
  );
}
