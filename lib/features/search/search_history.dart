import 'package:flutter/foundation.dart';

/// Recent-search history (spec §6).
///
/// The store is an interface so the list can be persisted with whatever the
/// app already uses on the device, and unit-tested in memory without a plugin.
/// Nothing here touches the network: search history is local by definition, and
/// sending it anywhere would be a privacy decision the spec does not grant.
abstract interface class SearchHistoryStore {
  Future<List<String>> read();
  Future<void> write(List<String> entries);
}

final class MemorySearchHistoryStore implements SearchHistoryStore {
  MemorySearchHistoryStore([List<String> initial = const <String>[]])
    : _entries = List<String>.of(initial);

  List<String> _entries;

  @override
  Future<List<String>> read() async => List<String>.unmodifiable(_entries);

  @override
  Future<void> write(List<String> entries) async {
    _entries = List<String>.of(entries);
  }
}

final class SearchHistory extends ChangeNotifier {
  SearchHistory({SearchHistoryStore? store})
    : _store = store ?? MemorySearchHistoryStore();

  /// Short on purpose: a long list stops being "recent" and becomes a second
  /// search box the member has to read.
  static const maxEntries = 8;

  final SearchHistoryStore _store;
  List<String> _entries = const <String>[];
  bool _loaded = false;

  /// True once a search has been recorded locally.
  ///
  /// [load] is asynchronous, and a member can commit a search before the stored
  /// list has finished reading. Without this flag that late read overwrote the
  /// new entry with the (older, possibly empty) stored list.
  bool _mutated = false;

  List<String> get entries => List<String>.unmodifiable(_entries);
  bool get isEmpty => _entries.isEmpty;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    final stored = await _store.read();
    _loaded = true;
    if (_mutated) return;
    // Re-apply the invariants on read: a store written by an older build could
    // hold duplicates or an over-long list.
    _entries = _sanitize(stored);
    notifyListeners();
  }

  /// Records [raw] as the newest entry. Re-searching an existing term moves it
  /// to the front instead of adding a second identical row.
  Future<List<String>> record(String raw) async {
    final term = normalize(raw);
    if (term.isEmpty) return entries;
    final next = <String>[
      term,
      for (final entry in _entries)
        if (normalize(entry) != term) entry,
    ];
    _mutated = true;
    _entries = _sanitize(next);
    await _store.write(_entries);
    notifyListeners();
    return entries;
  }

  Future<void> remove(String raw) async {
    final term = normalize(raw);
    _mutated = true;
    _entries = <String>[
      for (final entry in _entries)
        if (normalize(entry) != term) entry,
    ];
    await _store.write(_entries);
    notifyListeners();
  }

  Future<void> clear() async {
    _mutated = true;
    _entries = const <String>[];
    await _store.write(const <String>[]);
    notifyListeners();
  }

  /// Same normalisation the query box uses, so `  Naruto ` and `naruto` are one
  /// history row rather than two.
  static String normalize(String raw) =>
      raw.trim().replaceAll(RegExp(r'\s+'), ' ');

  static List<String> _sanitize(List<String> input) {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in input) {
      final term = normalize(raw);
      if (term.isEmpty) continue;
      final key = term.toLowerCase();
      if (!seen.add(key)) continue;
      out.add(term);
      if (out.length >= maxEntries) break;
    }
    return List<String>.unmodifiable(out);
  }
}
