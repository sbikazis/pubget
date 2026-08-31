import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';

void main() {
  test('success exposes its value', () {
    const result = Success<int>(42);

    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull, 42);
    expect(result.failureOrNull, isNull);
  });

  test('failure exposes its typed error', () {
    const result = FailureResult<int>(PermissionError());

    expect(result.isSuccess, isFalse);
    expect(result.valueOrNull, isNull);
    expect(result.failureOrNull, isA<PermissionError>());
  });
}
