import 'package:flutter/foundation.dart';

final class AuthDraftStore extends ChangeNotifier {
  String _email = '';
  bool _acceptedTerms = false;

  String get email => _email;
  bool get acceptedTerms => _acceptedTerms;

  void setEmail(String value) {
    if (_email == value) return;
    _email = value;
    notifyListeners();
  }

  void setAcceptedTerms(bool value) {
    if (_acceptedTerms == value) return;
    _acceptedTerms = value;
    notifyListeners();
  }

  void clear() {
    _email = '';
    _acceptedTerms = false;
    notifyListeners();
  }
}
