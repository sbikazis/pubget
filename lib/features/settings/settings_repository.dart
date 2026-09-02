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
