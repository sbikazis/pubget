import 'dart:math';

import 'media_kind.dart';

/// Storage key format: `{folder}/{ownerUid}/{uuid}.{ext}` — for example
/// `images/abc123/9f1c…-….jpg`.
///
/// Rules this enforces:
/// * the object name is generated, never a user-supplied file name;
/// * the owner's UID is part of the path, so ownership is checkable from the
///   key alone (list scoping, delete authorization, no cross-user overwrite);
/// * the folder comes from the kind, so limits can be applied per prefix.
/// Builds a fresh, unguessable storage key.
///
/// [random] is injectable for tests; production passes `Random.secure()`.
String buildMediaKey({
  required MediaKind kind,
  required String ownerUid,
  required String extension,
  required Random random,
}) {
  assert(ownerUid.trim().isNotEmpty, 'ownerUid is required to build a key');
  final ext = extension.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  final suffix = ext.isEmpty ? '' : '.$ext';
  return '${kind.folder}/$ownerUid/${generateMediaId(random)}$suffix';
}

/// A random v4-shaped identifier (36 chars). Not a user-visible ID — used
/// both for object names and as the Firestore `mediaId`.
String generateMediaId(Random random) {
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Splits a storage key into its segments, or null when it is malformed.
List<String>? parseMediaKey(String key) {
  final segments = key.split('/');
  if (segments.length != 3) return null;
  final folder = segments[0];
  final uid = segments[1];
  final name = segments[2];
  if (MediaKind.fromFolder(folder) == null) return null;
  if (uid.isEmpty || !_isSafeSegment(uid)) return null;
  if (name.isEmpty || !name.contains('.')) return null;
  if (!_isSafeName(name)) return null;
  return segments;
}

/// The folder segment of [key], or null when malformed.
String? mediaKeyFolder(String key) => parseMediaKey(key)?[0];

/// The owner UID encoded in [key], or null when malformed.
String? mediaKeyOwnerUid(String key) => parseMediaKey(key)?[1];

/// True when [key] is well-formed and belongs to [ownerUid]. Used before any
/// write or delete so a caller can never address another user's object.
bool keyOwnedBy(String key, String ownerUid) =>
    parseMediaKey(key) != null && mediaKeyOwnerUid(key) == ownerUid;

bool _isSafeSegment(String value) {
  const allowed =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_';
  for (final rune in value.runes) {
    if (!allowed.contains(String.fromCharCode(rune))) return false;
  }
  return true;
}

/// Object names additionally carry an extension, so `.` is allowed — but only
/// as an interior single dot: no leading/trailing dot and no `..`.
bool _isSafeName(String value) {
  if (value.startsWith('.') || value.endsWith('.')) return false;
  if (value.contains('..')) return false;
  const allowed =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.';
  for (final rune in value.runes) {
    if (!allowed.contains(String.fromCharCode(rune))) return false;
  }
  return true;
}
