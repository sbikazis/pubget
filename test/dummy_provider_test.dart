import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/examples/dummy_provider.dart';
import 'package:pubget/core/examples/dummy_repository.dart';
import 'package:pubget/core/loading/loading_state.dart';

void main() {
  test('dummy provider follows the documented loading contract', () async {
    final provider = DummyProvider(repository: DummyRepository());

    expect(provider.state, LoadingState.initial);

    await provider.load();

    expect(provider.state, LoadingState.loaded);
    expect(provider.greeting, 'Repository result');
    expect(provider.lastResult?.isSuccess, isTrue);
  });
}
