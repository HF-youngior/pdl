import 'package:flutter/material.dart';

class AppSettings extends ChangeNotifier {
  static final AppSettings instance = AppSettings._internal();
  AppSettings._internal();

  bool _notificationsEnabled = true;
  bool _darkMode = false;
  String _language = 'zh'; // 'zh' or 'en'

  bool get notificationsEnabled => _notificationsEnabled;
  bool get darkMode => _darkMode;
  String get language => _language;

  ThemeMode get themeMode => _darkMode ? ThemeMode.dark : ThemeMode.light;
  Locale get locale => Locale(_language);

  void setNotificationsEnabled(bool value) {
    if (_notificationsEnabled == value) return;
    _notificationsEnabled = value;
    notifyListeners();
  }

  void setDarkMode(bool value) {
    if (_darkMode == value) return;
    _darkMode = value;
    notifyListeners();
  }

  void setLanguage(String code) {
    if (_language == code) return;
    _language = code;
    notifyListeners();
  }
}


