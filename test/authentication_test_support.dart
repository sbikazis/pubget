import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/network/network_service.dart';
import 'package:pubget/core/theme/app_theme.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/models/pubget_user.dart';
import 'package:pubget/features/authentication/providers/auth_draft_store.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';
import 'package:pubget/features/authentication/providers/onboarding_provider.dart';
import 'package:pubget/features/authentication/repositories/auth_repository.dart';
import 'package:pubget/features/authentication/repositories/user_repository.dart';

final class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.user, this.authFailure, this.resetFailure});

  AuthUser? user;
  Failure? authFailure;
  Failure? resetFailure;
  Duration? authDelay;
  var emailSignInCalls = 0;
  var signUpCalls = 0;
  var googleCalls = 0;
  final _controller = StreamController<AuthUser?>.broadcast();

  @override
  AuthUser? get currentUser => user;

  @override
  Stream<AuthUser?> get authStateChanges => _controller.stream;

  @override
  Future<Result<AuthUser>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    emailSignInCalls++;
    return _authenticate(email);
  }

  @override
  Future<Result<AuthUser>> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    signUpCalls++;
    return _authenticate(email);
  }

  @override
  Future<Result<AuthUser>> signInWithGoogle() async {
    googleCalls++;
    return _authenticate('google@example.com');
  }

  @override
  Future<Result<void>> sendPasswordResetEmail({required String email}) async {
    final failure = resetFailure;
    return failure == null
        ? const Success<void>(null)
        : FailureResult<void>(failure);
  }

  @override
  Future<Result<void>> signOut() async {
    user = null;
    _controller.add(null);
    return const Success<void>(null);
  }

  Future<Result<AuthUser>> _authenticate(String email) async {
    final delay = authDelay;
    if (delay != null) await Future<void>.delayed(delay);
    final failure = authFailure;
    if (failure != null) return FailureResult<AuthUser>(failure);
    user = AuthUser(id: 'user-1', email: email);
    _controller.add(user);
    return Success<AuthUser>(user!);
  }

  Future<void> close() => _controller.close();
}

final class FakeUserRepository implements UserRepository {
  PubgetUser? user;
  Failure? failure;
  int avatarUploads = 0;

  @override
  Future<Result<PubgetUser>> createUserProfile(PubgetUser user) async =>
      _save(user);

  @override
  Future<Result<PubgetUser?>> getUserProfile(String userId) async {
    final currentFailure = failure;
    return currentFailure == null
        ? Success<PubgetUser?>(user)
        : FailureResult<PubgetUser?>(currentFailure);
  }

  @override
  Future<Result<PubgetUser>> updateUserProfile(PubgetUser user) async =>
      _save(user);

  @override
  Future<Result<String>> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    avatarUploads++;
    final currentFailure = failure;
    return currentFailure == null
        ? const Success<String>('https://example.com/avatar.jpg')
        : FailureResult<String>(currentFailure);
  }

  Result<PubgetUser> _save(PubgetUser next) {
    final currentFailure = failure;
    if (currentFailure != null) {
      return FailureResult<PubgetUser>(currentFailure);
    }
    user = next;
    return Success<PubgetUser>(next);
  }
}

Future<void> pumpAuthScreen(
  WidgetTester tester, {
  required Widget child,
  FakeAuthRepository? repository,
  FakeUserRepository? users,
  NetworkService? network,
  AuthDraftStore? draft,
  ThemeMode themeMode = ThemeMode.system,
  TextDirection textDirection = TextDirection.ltr,
}) async {
  final createdNetwork = network == null;
  final resolvedNetwork = network ?? NetworkService(probe: () async => true);
  if (createdNetwork) {
    await resolvedNetwork.refresh();
    addTearDown(resolvedNetwork.dispose);
  }
  final createdRepository = repository == null;
  final authRepository = repository ?? FakeAuthRepository();
  if (createdRepository) {
    addTearDown(authRepository.close);
  }
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<NetworkService>.value(value: resolvedNetwork),
        ChangeNotifierProvider<AuthDraftStore>.value(
          value: draft ?? AuthDraftStore(),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(repository: authRepository),
        ),
        ChangeNotifierProvider<OnboardingProvider>(
          create: (_) =>
              OnboardingProvider(repository: users ?? FakeUserRepository()),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        home: Directionality(textDirection: textDirection, child: child),
      ),
    ),
  );
}
