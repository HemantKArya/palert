import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _colorSchemeKey = 'color_scheme';
  static const String _refreshIntervalKey = 'refresh_interval';

  ThemeMode _themeMode = ThemeMode.system;
  String _colorScheme = 'blue'; // Default color scheme
  int _refreshInterval = 30; // Default refresh interval in minutes

  SharedPreferences? _prefs;

  ThemeProvider() {
    _loadSettings();
  }

  // Getters
  ThemeMode get themeMode => _themeMode;
  String get colorScheme => _colorScheme;
  int get refreshInterval => _refreshInterval;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    } else {
      return _themeMode == ThemeMode.dark;
    }
  }

  // Available color schemes
  static const Map<String, ColorSwatch> colorSchemes = {
    'blue': Colors.blue,
    'green': Colors.green,
    'purple': Colors.purple,
    'orange': Colors.orange,
    'red': Colors.red,
    'teal': Colors.teal,
    'indigo': Colors.indigo,
    'pink': Colors.pink,
  };

  // Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();

    // Load theme mode
    final themeModeIndex = _prefs?.getInt(_themeModeKey) ?? 0;
    _themeMode = ThemeMode.values[themeModeIndex];

    // Load color scheme
    _colorScheme = _prefs?.getString(_colorSchemeKey) ?? 'blue';

    // Load refresh interval
    _refreshInterval = _prefs?.getInt(_refreshIntervalKey) ?? 30;

    notifyListeners();
  }

  // Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    await _prefs?.setInt(_themeModeKey, _themeMode.index);
    await _prefs?.setString(_colorSchemeKey, _colorScheme);
    await _prefs?.setInt(_refreshIntervalKey, _refreshInterval);
  }

  // Update theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _saveSettings();
    notifyListeners();
  }

  // Toggle theme (for backward compatibility)
  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    await _saveSettings();
    notifyListeners();
  }

  // Update color scheme
  Future<void> setColorScheme(String scheme) async {
    if (colorSchemes.containsKey(scheme)) {
      _colorScheme = scheme;
      await _saveSettings();
      notifyListeners();
    }
  }

  // Update refresh interval
  Future<void> setRefreshInterval(int minutes) async {
    _refreshInterval = minutes;
    await _saveSettings();
    notifyListeners();
  }

  // Get current color based on selected scheme
  Color get primaryColor => colorSchemes[_colorScheme] ?? Colors.blue;
}
