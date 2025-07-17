import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsProvider extends ChangeNotifier {
  static const String _priceDropEnabledKey = 'notification_price_drop_enabled';
  static const String _backInStockEnabledKey = 'notification_back_in_stock_enabled';
  static const String _priceIncreaseEnabledKey = 'notification_price_increase_enabled';
  static const String _outOfStockEnabledKey = 'notification_out_of_stock_enabled';

  // Default values - price drop notifications are enabled by default
  bool _priceDropEnabled = true;
  bool _backInStockEnabled = false;
  bool _priceIncreaseEnabled = false;
  bool _outOfStockEnabled = false;

  SharedPreferences? _prefs;

  NotificationSettingsProvider() {
    _loadSettings();
  }

  // Getters
  bool get priceDropEnabled => _priceDropEnabled;
  bool get backInStockEnabled => _backInStockEnabled;
  bool get priceIncreaseEnabled => _priceIncreaseEnabled;
  bool get outOfStockEnabled => _outOfStockEnabled;

  // Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();

    _priceDropEnabled = _prefs?.getBool(_priceDropEnabledKey) ?? true;
    _backInStockEnabled = _prefs?.getBool(_backInStockEnabledKey) ?? false;
    _priceIncreaseEnabled = _prefs?.getBool(_priceIncreaseEnabledKey) ?? false;
    _outOfStockEnabled = _prefs?.getBool(_outOfStockEnabledKey) ?? false;

    notifyListeners();
  }

  // Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    await _prefs?.setBool(_priceDropEnabledKey, _priceDropEnabled);
    await _prefs?.setBool(_backInStockEnabledKey, _backInStockEnabled);
    await _prefs?.setBool(_priceIncreaseEnabledKey, _priceIncreaseEnabled);
    await _prefs?.setBool(_outOfStockEnabledKey, _outOfStockEnabled);
  }

  // Update individual notification settings
  Future<void> setPriceDropEnabled(bool enabled) async {
    _priceDropEnabled = enabled;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setBackInStockEnabled(bool enabled) async {
    _backInStockEnabled = enabled;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setPriceIncreaseEnabled(bool enabled) async {
    _priceIncreaseEnabled = enabled;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setOutOfStockEnabled(bool enabled) async {
    _outOfStockEnabled = enabled;
    await _saveSettings();
    notifyListeners();
  }

  // Check if any notifications are enabled
  bool get hasAnyNotificationEnabled {
    return _priceDropEnabled || _backInStockEnabled || _priceIncreaseEnabled || _outOfStockEnabled;
  }
}
