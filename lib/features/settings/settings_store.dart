import 'package:flutter/material.dart';

enum AppLocaleOption { system, english, arabic }

final class SettingsSnapshot {
  const SettingsSnapshot({
    this.themeMode = ThemeMode.system,
    this.localeOption = AppLocaleOption.system,
  });

  final ThemeMode themeMode;
  final AppLocaleOption localeOption;

  Locale? get locale => switch (localeOption) {
    AppLocaleOption.system => null,
    AppLocaleOption.english => const Locale('en'),
    AppLocaleOption.arabic => const Locale('ar'),
  };

  SettingsSnapshot copyWith({
    ThemeMode? themeMode,
    AppLocaleOption? localeOption,
  }) => SettingsSnapshot(
    themeMode: themeMode ?? this.themeMode,
    localeOption: localeOption ?? this.localeOption,
  );

  Map<String, String> toStorage() => <String, String>{
    'themeMode': themeMode.name,
    'locale': localeOption.name,
  };

  static SettingsSnapshot fromStorage(Map<String, String> values) {
    return SettingsSnapshot(
      themeMode: ThemeMode.values.firstWhere(
        (value) => value.name == values['themeMode'],
        orElse: () => ThemeMode.system,
      ),
      localeOption: AppLocaleOption.values.firstWhere(
        (value) => value.name == values['locale'],
        orElse: () => AppLocaleOption.system,
      ),
    );
  }
}

abstract interface class SettingsStore {
  Future<Map<String, String>> read();
  Future<void> write(Map<String, String> values);
}

final class MemorySettingsStore implements SettingsStore {
  MemorySettingsStore([Map<String, String>? seed])
    : _values = Map<String, String>.from(seed ?? const <String, String>{});

  final Map<String, String> _values;

  @override
  Future<Map<String, String>> read() async =>
      Map<String, String>.unmodifiable(_values);

  @override
  Future<void> write(Map<String, String> values) async {
    _values
      ..clear()
      ..addAll(values);
  }
}
