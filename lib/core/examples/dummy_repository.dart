import '../errors/result.dart';

/// Small, domain-free example of the Repository boundary.
class DummyRepository {
  Future<Result<String>> loadGreeting() async {
    return const Success<String>('Repository result');
  }
}
