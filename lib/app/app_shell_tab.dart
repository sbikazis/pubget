enum AppShellTab { discover, groups, private, edits }

extension AppShellTabX on AppShellTab {
  String get path => switch (this) {
    AppShellTab.discover => '/home',
    AppShellTab.groups => '/groups',
    AppShellTab.private => '/private',
    AppShellTab.edits => '/edits',
  };

  String get label => switch (this) {
    AppShellTab.discover => 'Discover',
    AppShellTab.groups => 'Groups',
    AppShellTab.private => 'Private',
    AppShellTab.edits => 'Edits',
  };

  static AppShellTab fromPath(String path) {
    return switch (path) {
      '/groups' => AppShellTab.groups,
      '/private' => AppShellTab.private,
      '/edits' => AppShellTab.edits,
      _ => AppShellTab.discover,
    };
  }
}
