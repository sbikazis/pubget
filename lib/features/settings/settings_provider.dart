import 'package:flutter/material.dart';

import '../../../core/loading/loading_state.dart';
import 'settings_repository.dart';
import 'settings_store.dart';

final class SettingsProvider extends ChangeNotifier {
  SettingsProvider({required SettingsRepository repository})
    : _repository = repository;

  final SettingsRepository _repository;
  SettingsSnapshot _snapshot = const SettingsSnapshot();
  LoadingState _state = LoadingState.initial;
  String? _failure;
  bool _disposed = false;

  SettingsSnapshot get snapshot => _snapshot;
  ThemeMode get themeMode => _snapshot.themeMode;
  Locale? get locale => _snapshot.locale;
  AppLocaleOption get localeOption => _snapshot.localeOption;
  LoadingState get state => _state;
  String? get failure => _failure;

  Future<void> load() async {
    _state = LoadingState.loading;
    _failure = null;
    _notify();
    final result = await _repository.load();
    result.fold(
      onSuccess: (value) {
        _snapshot = value;
        _state = LoadingState.loaded;
      },
      onFailure: (error) {
        _failure = error.message;
        _state = LoadingState.loaded;
      },
    );
    _notify();
  }

  Future<bool> setThemeMode(ThemeMode mode) =>
      _commit(_snapshot.copyWith(themeMode: mode));

  Future<bool> setLocaleOption(AppLocaleOption option) =>
      _commit(_snapshot.copyWith(localeOption: option));

  /// Seeds the language from the server profile on a fresh device only.
  /// An explicit device choice always wins (spec §1.4); this is why the
  /// splash screen can safely call it on every authenticated launch.
  Future<void> seedLanguageFromServer(String language) async {
    final normalized = language.trim().toLowerCase();
    if (normalized != 'ar' && normalized != 'en') return;
    if (await _repository.hasExplicitLocaleChoice()) return;
    final option = normalized == 'ar'
        ? AppLocaleOption.arabic
        : AppLocaleOption.english;
    if (_snapshot.localeOption == option) return;
    await _commit(_snapshot.copyWith(localeOption: option));
  }

  Future<bool> _commit(SettingsSnapshot next) async {
    final previous = _snapshot;
    _snapshot = next;
    _failure = null;
    _notify();
    final result = await _repository.save(next);
    return result.fold(
      onSuccess: (_) => true,
      onFailure: (error) {
        _snapshot = previous;
        _failure = error.message;
        _notify();
        return false;
      },
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
