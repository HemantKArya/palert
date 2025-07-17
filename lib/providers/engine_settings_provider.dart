import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class EngineSettingsProvider extends ChangeNotifier {
  static const String _portKey = 'engine_port';
  static const String _dbPathKey = 'engine_db_path';
  static const String _browserPathKey = 'engine_browser_path';
  static const String _webdriverPathKey = 'engine_webdriver_path';

  int _port = 9222; // Default port
  String _dbPath = "palert_db.sqlite"; // Default db path
  String _browserPath =
      "C:\\Program Files\\BraveSoftware\\Brave-Browser\\Application\\brave.exe"; // Default browser path
  String _webdriverPath = "chromedriver.exe"; // Default webdriver path

  SharedPreferences? _prefs;

  EngineSettingsProvider() {
    _loadSettings();
  }

  // Getters
  int get port => _port;
  String get dbPath => _dbPath;
  String get browserPath => _browserPath;
  String get webdriverPath => _webdriverPath;

  // Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();

    _port = _prefs?.getInt(_portKey) ?? 9222;
    _dbPath = _prefs?.getString(_dbPathKey) ?? "palert_db.sqlite";
    _browserPath = _prefs?.getString(_browserPathKey) ??
        "C:\\Program Files\\BraveSoftware\\Brave-Browser\\Application\\brave.exe";
    _webdriverPath = _prefs?.getString(_webdriverPathKey) ?? "chromedriver.exe";

    notifyListeners();
  }

  // Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    await _prefs?.setInt(_portKey, _port);
    await _prefs?.setString(_dbPathKey, _dbPath);
    await _prefs?.setString(_browserPathKey, _browserPath);
    await _prefs?.setString(_webdriverPathKey, _webdriverPath);
  }

  // Update port
  Future<void> setPort(int port) async {
    if (port > 0 && port < 65536) {
      _port = port;
      await _saveSettings();
      notifyListeners();
    }
  }

  // Update database path
  Future<void> setDbPath(String path) async {
    if (path.isNotEmpty) {
      _dbPath = path;
      await _saveSettings();
      notifyListeners();
    }
  }

  // Update browser path
  Future<void> setbrowserPath(String path) async {
    if (path.isNotEmpty) {
      _browserPath = path;
      await _saveSettings();
      notifyListeners();
    }
  }

  // Update webdriver path
  Future<void> setWebdriverPath(String path) async {
    if (path.isNotEmpty) {
      _webdriverPath = path;
      await _saveSettings();
      notifyListeners();
    }
  }

  // Validate port range
  bool isValidPort(int port) {
    return port > 0 && port < 65536;
  }

  // Validate if browser path exists
  bool isValidbrowserPath(String path) {
    return path.isNotEmpty && File(path).existsSync();
  }

  // Validate if webdriver path exists
  bool isValidWebdriverPath(String path) {
    return path.isNotEmpty && File(path).existsSync();
  }

  // Get validation message for current settings
  String? getValidationMessage() {
    if (!isValidPort(_port)) {
      return 'Port must be between 1 and 65535';
    }
    if (_dbPath.isEmpty) {
      return 'Database path cannot be empty';
    }
    if (_browserPath.isEmpty) {
      return 'browser path cannot be empty';
    }
    if (!isValidbrowserPath(_browserPath)) {
      return 'browser path does not exist: $_browserPath';
    }
    if (_webdriverPath.isEmpty) {
      return 'Webdriver path cannot be empty';
    }
    if (!isValidWebdriverPath(_webdriverPath)) {
      return 'Webdriver path does not exist: $_webdriverPath';
    }
    return null; // All settings are valid
  }

  // Get common browser paths for suggestions
  static List<String> getCommonBrowserPaths() {
    return [
      "C:\\Program Files\\BraveSoftware\\Brave-Browser\\Application\\brave.exe",
      "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
      "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe",
      "C:\\Program Files\\Mozilla Firefox\\firefox.exe",
      "C:\\Program Files (x86)\\Mozilla Firefox\\firefox.exe",
      "C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe",
    ];
  }

  // Get common webdriver paths for suggestions
  static List<String> getCommonWebdriverPaths() {
    return [
      "chromedriver.exe",
      "C:\\WebDrivers\\chromedriver.exe",
      "C:\\Windows\\System32\\chromedriver.exe",
      "geckodriver.exe",
      "C:\\WebDrivers\\geckodriver.exe",
      "edgedriver.exe",
      "C:\\WebDrivers\\msedgedriver.exe",
    ];
  }
}
