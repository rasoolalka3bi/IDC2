import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api.dart';
import '../data/demo_repository.dart';
import '../data/models.dart';
import '../data/repository.dart';

/// حالة التطبيق العامة: الجلسة، مصدر البيانات، الوضع الليلي، البصمة.
class AppState extends ChangeNotifier {
  static const _kUser = 'user';
  static const _kTheme = 'theme_mode';
  static const _kBiometric = 'biometric';
  static const _kDemo = 'demo';

  final FlutterSecureStorage _secure;
  final SharedPreferences _prefs;
  final Repository _api;
  final Repository _demo;

  AppState(this._prefs, {FlutterSecureStorage? secure, Repository? api, Repository? demo})
      : _secure = secure ?? const FlutterSecureStorage(),
        _api = api ?? ApiRepository(),
        _demo = demo ?? DemoRepository();

  User? _user;
  bool _ready = false;
  int _unread = 0;

  User? get user => _user;
  bool get ready => _ready;
  bool get signedIn => _user != null;
  bool get isDemo => _prefs.getBool(_kDemo) ?? false;
  Repository get repo => isDemo ? _demo : _api;
  int get unread => _unread;

  ThemeMode get themeMode => ThemeMode.values[_prefs.getInt(_kTheme) ?? ThemeMode.system.index];
  bool get biometricEnabled => _prefs.getBool(_kBiometric) ?? false;

  /// هل توجد جلسة محفوظة يمكن فتحها بالبصمة؟
  bool _hasSaved = false;
  bool get hasSavedSession => _hasSaved;

  Future<void> load() async {
    try {
      final raw = await _secure.read(key: _kUser);
      if (raw != null) {
        final u = User.fromJson(jsonDecode(raw) as Map);
        _hasSaved = true;
        // عند تفعيل البصمة لا تفتح الجلسة إلا بعد التحقق.
        if (!biometricEnabled) _setUser(u);
      }
    } catch (_) {
      await _secure.delete(key: _kUser);
    }
    _ready = true;
    notifyListeners();
  }

  void _setUser(User? u) {
    _user = u;
    repo.attach(u);
    if (u != null) refreshUnread();
  }

  Future<void> signIn(String username, String password, {bool demo = false}) async {
    await _prefs.setBool(_kDemo, demo);
    final u = await repo.login(username, password);
    await _secure.write(key: _kUser, value: jsonEncode(u.toJson()));
    _hasSaved = true;
    _setUser(u);
    notifyListeners();
  }

  /// يفتح الجلسة المحفوظة بعد نجاح التحقق بالبصمة.
  Future<bool> unlockSaved() async {
    final raw = await _secure.read(key: _kUser);
    if (raw == null) return false;
    _setUser(User.fromJson(jsonDecode(raw) as Map));
    notifyListeners();
    return true;
  }

  Future<void> signOut() async {
    await _secure.delete(key: _kUser);
    await _prefs.remove(_kDemo);
    await _prefs.remove(_kBiometric);
    _hasSaved = false;
    _unread = 0;
    _setUser(null);
    notifyListeners();
  }

  Future<void> updateUserImage(String? url) async {
    final u = _user;
    if (u == null || url == null) return;
    _user = u.copyWith(imageUrl: url);
    await _secure.write(key: _kUser, value: jsonEncode(_user!.toJson()));
    notifyListeners();
  }

  Future<void> refreshUnread() async {
    try {
      _unread = await repo.unreadCount();
      notifyListeners();
    } catch (_) {}
  }

  void markAllRead() {
    if (_unread == 0) return;
    _unread = 0;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode m) async {
    await _prefs.setInt(_kTheme, m.index);
    notifyListeners();
  }

  Future<void> setBiometric(bool v) async {
    await _prefs.setBool(_kBiometric, v);
    notifyListeners();
  }
}
