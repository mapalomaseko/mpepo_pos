import 'package:flutter/foundation.dart';

class AuthProvider extends ChangeNotifier {
  static const _username = 'admin';
  static const _password = 'admin123';

  bool _isAuthenticated = false;

  bool get isAuthenticated => _isAuthenticated;

  Future<bool> login(String username, String password) async {
    final sanitizedUsername = username.trim();
    if (sanitizedUsername == _username && password == _password) {
      _isAuthenticated = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  void logout() {
    if (_isAuthenticated) {
      _isAuthenticated = false;
      notifyListeners();
    }
  }
}
