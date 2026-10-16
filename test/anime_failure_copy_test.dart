import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/features/anime/l10n/anime_copy.dart';
import 'package:pubget/features/anime/l10n/anime_failure_copy.dart';

void main() {
  final en = AnimeCopy.forLocale(const Locale('en'));
  final ar = AnimeCopy.forLocale(const Locale('ar'));

  test(
    'a real connectivity failure asks the member to check the connection',
    () {
      expect(animeFailureMessage(en, const NetworkError()), en.checkConnection);
      expect(animeFailureMessage(en, const TimeoutError()), en.checkConnection);
    },
  );

  test('a backend hiccup is never reported as a connection problem', () {
    final message = animeFailureMessage(en, const UnavailableError());
    expect(message, en.serviceUnavailable);
    expect(message.toLowerCase(), isNot(contains('connection')));
  });

  test('a throttle gets its own advice, not a connection check', () {
    expect(
      animeFailureMessage(en, const RateLimitedError()),
      en.tooManyRequests,
    );
    expect(
      animeFailureMessage(ar, const RateLimitedError()),
      ar.tooManyRequests,
    );
  });

  test('a permission failure points the member at signing in', () {
    expect(
      animeFailureMessage(en, const PermissionError()),
      en.signInToSaveList,
    );
  });

  test('the resolved sentence is localized, never the raw failure message', () {
    // The failure's own sentence is locale-neutral English; the UI copy is not.
    const failure = UnavailableError('Something went wrong on our side.');
    expect(animeFailureMessage(ar, failure), isNot(contains('Something')));
    expect(
      animeFailureMessage(ar, failure),
      isNot(animeFailureMessage(en, failure)),
    );
    expect(animeFailureMessage(ar, failure), isNotEmpty);
  });

  test('a null failure still returns non-empty, non-connectivity copy', () {
    // With no failure object we cannot claim a connectivity problem, so the
    // generic outage copy is the honest default.
    expect(animeFailureMessage(en, null), en.serviceUnavailable);
    expect(animeFailureMessage(ar, null), isNotEmpty);
  });
}
