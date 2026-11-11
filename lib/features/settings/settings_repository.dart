import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import 'settings_store.dart';

final class SettingsRepository {
  SettingsRepository({required SettingsStore store}) : _store = store;

  final SettingsStore _store;
  SettingsSnapshot? _cached;

  SettingsSnapshot get current => _cached ?? const SettingsSnapshot();

  Future<Result<SettingsSnapshot>> load() async {
    try {
      final stored = await _store.read();
      _cached = SettingsSnapshot.fromStorage(stored);
      return Success(_cached!);
    } on Object {
      return const FailureResult(
        UnknownError('Preferences could not be loaded.'),
      );
    }
  }

  /// True once the user has explicitly picked a language on this device.
  /// A server-side language seed must never overwrite that choice (spec §1.4).
  Future<bool> hasExplicitLocaleChoice() async {
    try {
      final stored = await _store.read();
      return stored.containsKey('locale');
    } on Object {
      return false;
    }
  }

  Future<Result<SettingsSnapshot>> save(SettingsSnapshot snapshot) async {
    final previous = current;
    _cached = snapshot;
    try {
      await _store.write(snapshot.toStorage());
      return Success(snapshot);
    } on Object {
      _cached = previous;
      return const FailureResult(
        UnknownError('Preferences could not be saved. Previous values kept.'),
      );
    }
  }
}
