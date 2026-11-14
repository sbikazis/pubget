import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/app/app_version_gate.dart';

void main() {
  test('compares numeric version segments rather than strings', () {
    expect(AppVersionGate.compareVersions('1.10.0', '1.9.9'), greaterThan(0));
    expect(AppVersionGate.compareVersions('1.2.0', '1.2'), 0);
    expect(AppVersionGate.compareVersions('1.2.3', '1.2.4'), lessThan(0));
    expect(AppVersionGate.compareVersions('2.0.0+18', '1.99.99'), greaterThan(0));
  });
}
