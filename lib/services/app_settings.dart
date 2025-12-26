import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  static final AppSettings instance = AppSettings._internal();
  AppSettings._internal();

  static const _keyNotifications = 'settings_notifications_enabled';
  static const _keyDarkMode = 'settings_dark_mode';
  static const _keyLanguage = 'settings_language';
  static const _keyEquippedLoopyId = 'settings_equipped_loopy_id';
  static const _keyEquippedLoopyAsset = 'settings_equipped_loopy_asset';
  static const _keyEquippedLoopyExpiry = 'settings_equipped_loopy_expiry';
  static const _keyRedeemedLoopies = 'settings_redeemed_loopy_rewards';
  static const _keyThemeColor = 'settings_theme_color';

  SharedPreferences? _prefs;
  bool _initialized = false;

  bool _notificationsEnabled = true;
  bool _darkMode = false;
  String _language = 'zh'; // 'zh' or 'en'
  // 默认主题色同步为加深后的马卡龙蓝
  Color _themeColor = const Color(0xFF4A90E2);
  String? _equippedLoopyId;
  String? _equippedLoopyAssetPath;
  DateTime? _equippedLoopyExpiry;
  final Map<String, DateTime> _redeemedLoopyRewards = {};

  bool get notificationsEnabled => _notificationsEnabled;
  bool get darkMode => _darkMode;
  String get language => _language;
  String? get equippedLoopyId => _equippedLoopyId;
  String? get equippedLoopyAssetPath => _equippedLoopyAssetPath;
  DateTime? get equippedLoopyExpiry => _equippedLoopyExpiry;
  Map<String, DateTime> get redeemedLoopyRewards => Map.unmodifiable(_redeemedLoopyRewards);
  Color get themeColor => _themeColor;

  ThemeMode get themeMode => _darkMode ? ThemeMode.dark : ThemeMode.light;
  Locale get locale => Locale(_language);

  Future<void> initialize() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = _prefs?.getBool(_keyNotifications) ?? true;
    _darkMode = _prefs?.getBool(_keyDarkMode) ?? false;
    _language = _prefs?.getString(_keyLanguage) ?? 'zh';
    _equippedLoopyId = _prefs?.getString(_keyEquippedLoopyId);
    _equippedLoopyAssetPath = _prefs?.getString(_keyEquippedLoopyAsset);
    final expiryIso = _prefs?.getString(_keyEquippedLoopyExpiry);
    if (expiryIso != null) {
      _equippedLoopyExpiry = DateTime.tryParse(expiryIso);
    }
    final storedThemeColor = _prefs?.getString(_keyThemeColor);
    if (storedThemeColor != null) {
      final decoded = _decodeColor(storedThemeColor);
      if (decoded != null) {
        _themeColor = decoded;
      }
    }
    _loadRedeemedLoopyRewards();
    purgeExpiredLoopyRewards(save: false);
    _initialized = true;
  }

  void setNotificationsEnabled(bool value) {
    if (_notificationsEnabled == value) return;
    _notificationsEnabled = value;
    _persist(_prefs?.setBool(_keyNotifications, value));
    notifyListeners();
  }

  void setDarkMode(bool value) {
    if (_darkMode == value) return;
    _darkMode = value;
    _persist(_prefs?.setBool(_keyDarkMode, value));
    notifyListeners();
  }

  void setLanguage(String code) {
    if (_language == code) return;
    _language = code;
    _persist(_prefs?.setString(_keyLanguage, code));
    notifyListeners();
  }

  void setThemeColor(Color color) {
    if (_themeColor == color) return;
    _themeColor = color;
    _persist(_prefs?.setString(_keyThemeColor, _encodeColor(color)));
    notifyListeners();
  }

  /// 装扮 Loopy，到期时间仅用于展示
  void equipLoopy({
    required String id,
    required String assetPath,
    required DateTime expiry,
  }) {
    _equippedLoopyId = id;
    _equippedLoopyAssetPath = assetPath;
    _equippedLoopyExpiry = expiry;
    _persist(_prefs?.setString(_keyEquippedLoopyId, id));
    _persist(_prefs?.setString(_keyEquippedLoopyAsset, assetPath));
    _persist(_prefs?.setString(_keyEquippedLoopyExpiry, expiry.toIso8601String()));
    notifyListeners();
  }

  /// 取消当前 Loopy 装扮
  void clearLoopy() {
    _equippedLoopyId = null;
    _equippedLoopyAssetPath = null;
    _equippedLoopyExpiry = null;
    _persist(_prefs?.remove(_keyEquippedLoopyId));
    _persist(_prefs?.remove(_keyEquippedLoopyAsset));
    _persist(_prefs?.remove(_keyEquippedLoopyExpiry));
    notifyListeners();
  }

  void markRewardRedeemed(String id, DateTime expiry) {
    _redeemedLoopyRewards[id] = expiry;
    _saveRedeemedLoopyRewards();
    notifyListeners();
  }

  void removeRedeemedReward(String id) {
    if (_redeemedLoopyRewards.remove(id) != null) {
      _saveRedeemedLoopyRewards();
      notifyListeners();
    }
  }

  void purgeExpiredLoopyRewards({bool save = true}) {
    final now = DateTime.now();
    final expiredIds = _redeemedLoopyRewards.entries
        .where((entry) => entry.value.isBefore(now))
        .map((entry) => entry.key)
        .toList();
    if (expiredIds.isEmpty) return;
    for (final id in expiredIds) {
      _redeemedLoopyRewards.remove(id);
    }
    if (save) {
      _saveRedeemedLoopyRewards();
    }
    notifyListeners();
  }

  /// 清空所有已兑换的 Loopy/奶龙记录（用于重置/调试）
  void clearAllRedeemedRewards() {
    _redeemedLoopyRewards.clear();
    _saveRedeemedLoopyRewards();
    notifyListeners();
  }

  void _loadRedeemedLoopyRewards() {
    final raw = _prefs?.getString(_keyRedeemedLoopies);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      decoded.forEach((id, iso) {
        if (iso is String) {
          final expiry = DateTime.tryParse(iso);
          if (expiry != null) {
            _redeemedLoopyRewards[id] = expiry;
          }
        }
      });
    } catch (_) {
      _redeemedLoopyRewards.clear();
    }
  }

  void _saveRedeemedLoopyRewards() {
    final map = _redeemedLoopyRewards.map(
      (key, value) => MapEntry(key, value.toIso8601String()),
    );
    _persist(_prefs?.setString(_keyRedeemedLoopies, json.encode(map)));
  }

  void _persist(Future<bool>? future) {
    if (future == null) return;
    unawaited(future);
  }

  String _encodeColor(Color color) => color.toString();

  Color? _decodeColor(String raw) {
    final match = RegExp(r'0x[0-9a-fA-F]{8}').firstMatch(raw);
    if (match == null) return null;
    final hex = match.group(0)!.substring(2);
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return null;
    return Color(value);
  }
}

