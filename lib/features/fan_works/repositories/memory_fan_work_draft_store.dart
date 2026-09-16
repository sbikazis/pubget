import 'fan_work_repository.dart';

final class MemoryFanWorkDraftStore implements FanWorkDraftStore {
  MemoryFanWorkDraftStore([Map<String, Map<String, dynamic>>? seed])
    : _data = seed ?? <String, Map<String, dynamic>>{};

  final Map<String, Map<String, dynamic>> _data;

  @override
  Future<void> write(String key, Map<String, dynamic> data) async {
    _data[key] = Map<String, dynamic>.from(data);
  }

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    final stored = _data[key];
    return stored == null ? null : Map<String, dynamic>.from(stored);
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}
