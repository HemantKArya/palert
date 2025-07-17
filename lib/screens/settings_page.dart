import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:palert/providers/theme_provider.dart';
import 'package:palert/providers/product_provider.dart';
import 'package:palert/providers/engine_settings_provider.dart';
import 'package:palert/providers/notification_settings_provider.dart';
import 'package:palert/services/price_engine_service.dart';
import 'package:palert/widgets/service_status_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Theme Settings Section
              _buildSectionHeader('Appearance', Icons.palette),
              const SizedBox(height: 8),
              _buildThemeModeCard(context, themeProvider),
              const SizedBox(height: 16),
              _buildColorSchemeCard(context, themeProvider),

              const SizedBox(height: 32),

              // App Settings Section
              _buildSectionHeader('App Settings', Icons.settings),
              const SizedBox(height: 8),
              _buildRefreshIntervalCard(context, themeProvider),
              const SizedBox(height: 16),
              _buildNotificationSettingsCard(context),

              const SizedBox(height: 32),

              // Engine Settings Section
              _buildSectionHeader(
                  'Engine Settings', Icons.settings_applications),
              const SizedBox(height: 8),
              _buildEngineSettingsCard(context),
              const SizedBox(height: 16),
              // Service Status Widget
              const ServiceStatusWidget(),

              const SizedBox(height: 32),

              // Data Management Section
              _buildSectionHeader('Data Management', Icons.backup),
              const SizedBox(height: 8),
              _buildBackupRestoreCard(context),

              const SizedBox(height: 32),

              // About Section
              _buildSectionHeader('About', Icons.info_outline),
              const SizedBox(height: 8),
              _buildAboutCard(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeModeCard(
      BuildContext context, ThemeProvider themeProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Theme Mode',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Column(
              children: ThemeMode.values.map((mode) {
                return RadioListTile<ThemeMode>(
                  title: Text(_getThemeModeLabel(mode)),
                  subtitle: Text(_getThemeModeDescription(mode)),
                  value: mode,
                  groupValue: themeProvider.themeMode,
                  onChanged: (ThemeMode? value) {
                    if (value != null) {
                      themeProvider.setThemeMode(value);
                    }
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSchemeCard(
      BuildContext context, ThemeProvider themeProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Color Scheme',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ThemeProvider.colorSchemes.entries.map((entry) {
                final isSelected = themeProvider.colorScheme == entry.key;
                return GestureDetector(
                  onTap: () => themeProvider.setColorScheme(entry.key),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: entry.value,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.onPrimary,
                            size: 24,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              'Current: ${_capitalize(themeProvider.colorScheme)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefreshIntervalCard(
      BuildContext context, ThemeProvider themeProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Auto-refresh Interval',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: themeProvider.refreshInterval,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [5, 10, 15, 30, 60, 120].map((minutes) {
                return DropdownMenuItem<int>(
                  value: minutes,
                  child: Text(_formatRefreshInterval(minutes)),
                );
              }).toList(),
              onChanged: (int? value) {
                if (value != null) {
                  themeProvider.setRefreshInterval(value);
                }
              },
            ),
            const SizedBox(height: 8),
            Text(
              'How often to automatically refresh product prices',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSettingsCard(BuildContext context) {
    return Consumer<NotificationSettingsProvider>(
      builder: (context, notificationSettings, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notification Settings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Configure which events trigger notifications',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),

                // Price Drop Notifications (enabled by default)
                _buildNotificationToggle(
                  context: context,
                  title: 'Price Drops',
                  subtitle: 'Get notified when prices drop',
                  icon: Icons.trending_down,
                  iconColor: Colors.green,
                  value: notificationSettings.priceDropEnabled,
                  onChanged: notificationSettings.setPriceDropEnabled,
                ),

                const SizedBox(height: 12),

                // Back in Stock Notifications
                _buildNotificationToggle(
                  context: context,
                  title: 'Back in Stock',
                  subtitle: 'Get notified when items are available again',
                  icon: Icons.inventory_2,
                  iconColor: Colors.blue,
                  value: notificationSettings.backInStockEnabled,
                  onChanged: notificationSettings.setBackInStockEnabled,
                ),

                const SizedBox(height: 12),

                // Price Increase Notifications
                _buildNotificationToggle(
                  context: context,
                  title: 'Price Increases',
                  subtitle: 'Get notified when prices go up',
                  icon: Icons.trending_up,
                  iconColor: Colors.orange,
                  value: notificationSettings.priceIncreaseEnabled,
                  onChanged: notificationSettings.setPriceIncreaseEnabled,
                ),

                const SizedBox(height: 12),

                // Out of Stock Notifications
                _buildNotificationToggle(
                  context: context,
                  title: 'Out of Stock',
                  subtitle: 'Get notified when items go out of stock',
                  icon: Icons.remove_shopping_cart,
                  iconColor: Colors.red,
                  value: notificationSettings.outOfStockEnabled,
                  onChanged: notificationSettings.setOutOfStockEnabled,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationToggle({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🛍️ Palert – Your Personal Price & Stock Tracker',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Version 1.0.0',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Palert is a lightweight, powerful desktop app that helps you track product prices and stock availability on Amazon and Flipkart. Stop checking websites manually and let Palert notify you about the best deals.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupRestoreCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Backup & Restore',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Create backups of your product data and restore from previous backups.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _createBackup(context),
                    icon: const Icon(Icons.backup),
                    label: const Text('Create Backup'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _restoreBackup(context),
                    icon: const Icon(Icons.restore),
                    label: const Text('Restore'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor:
                          Theme.of(context).colorScheme.onSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createBackup(BuildContext context) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Creating backup...'),
            ],
          ),
        ),
      );

      // Get directory to save the backup
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory == null) {
        if (context.mounted)
          Navigator.of(context).pop(); // Close loading dialog
        return;
      }

      // Generate filename with timestamp
      final timestamp =
          DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final backupPath =
          '$selectedDirectory${Platform.pathSeparator}ptrack_backup_$timestamp.json';

      // Get the price engine from ProductProvider
      final productProvider =
          Provider.of<ProductProvider>(context, listen: false);

      // Create the backup using Rust function
      await productProvider.createBackup(backupPath);

      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        // Show success dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Backup Created'),
            content: Text('Backup saved successfully to:\n$backupPath'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        // Show error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Backup Failed'),
            content: Text('Failed to create backup:\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _restoreBackup(BuildContext context) async {
    try {
      // Pick backup file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Select backup file to restore',
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      final backupPath = result.files.single.path!;

      // Show confirmation dialog
      bool? shouldReplace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restore Backup'),
          content: const Text(
            'Do you want to replace existing data or merge with current data?\n\n'
            'Replace: All current data will be deleted and replaced with backup data.\n'
            'Merge: Backup data will be added to existing data.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Merge'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );

      if (shouldReplace == null) return;

      // Show loading dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Restoring backup...'),
              ],
            ),
          ),
        );
      }

      // Get the price engine from ProductProvider
      final productProvider =
          Provider.of<ProductProvider>(context, listen: false);

      // Restore the backup using Rust function
      await productProvider.restoreFromBackup(backupPath, shouldReplace);

      // Refresh the product list
      await productProvider.loadProducts();

      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        // Show success dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Restore Complete'),
            content: const Text('Backup restored successfully!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        // Show error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Restore Failed'),
            content: Text('Failed to restore backup:\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Widget _buildEngineSettingsCard(BuildContext context) {
    return Consumer<EngineSettingsProvider>(
      builder: (context, engineSettings, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Engine Configuration',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Configure the price engine settings. Changes require app restart.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),

                // Port setting
                TextFormField(
                  initialValue: engineSettings.port.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Port Number',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    hintText: '9222',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final port = int.tryParse(value);
                    if (port != null && engineSettings.isValidPort(port)) {
                      engineSettings.setPort(port);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Database path setting
                TextFormField(
                  initialValue: engineSettings.dbPath,
                  decoration: const InputDecoration(
                    labelText: 'Database Path',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    hintText: 'palert_db.sqlite',
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty) {
                      engineSettings.setDbPath(value);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // browser path setting
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: engineSettings.browserPath,
                        decoration: const InputDecoration(
                          labelText: 'Browser Path',
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          hintText: 'Path to browser executable',
                        ),
                        onChanged: (value) {
                          if (value.isNotEmpty) {
                            engineSettings.setbrowserPath(value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      onPressed: () =>
                          _selectBrowserPath(context, engineSettings),
                      icon: const Icon(Icons.folder_open),
                      tooltip: 'Browse for browser executable',
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Common browser paths
                ExpansionTile(
                  title: const Text('Common Browser Paths'),
                  children: EngineSettingsProvider.getCommonBrowserPaths()
                      .map((path) {
                    return ListTile(
                      title: Text(
                        path,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                            ),
                      ),
                      dense: true,
                      onTap: () => engineSettings.setbrowserPath(path),
                      trailing: File(path).existsSync()
                          ? Icon(Icons.check_circle,
                              color: Colors.green, size: 16)
                          : Icon(Icons.error_outline,
                              color: Colors.red, size: 16),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Webdriver path setting
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: engineSettings.webdriverPath,
                        decoration: const InputDecoration(
                          labelText: 'Webdriver Path',
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          hintText:
                              'Path to webdriver executable (chromedriver.exe)',
                        ),
                        onChanged: (value) {
                          if (value.isNotEmpty) {
                            engineSettings.setWebdriverPath(value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      onPressed: () =>
                          _selectWebdriverPath(context, engineSettings),
                      icon: const Icon(Icons.folder_open),
                      tooltip: 'Browse for webdriver executable',
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Common webdriver paths
                ExpansionTile(
                  title: const Text('Common Webdriver Paths'),
                  children: EngineSettingsProvider.getCommonWebdriverPaths()
                      .map((path) {
                    return ListTile(
                      title: Text(
                        path,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                            ),
                      ),
                      dense: true,
                      onTap: () => engineSettings.setWebdriverPath(path),
                      trailing: File(path).existsSync()
                          ? Icon(Icons.check_circle,
                              color: Colors.green, size: 16)
                          : Icon(Icons.error_outline,
                              color: Colors.red, size: 16),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Validation message and restart engine button
                Builder(
                  builder: (context) {
                    final validationMessage =
                        engineSettings.getValidationMessage();
                    final isValid = validationMessage == null;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isValid) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    validationMessage,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onErrorContainer,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isValid
                                ? () => _restartEngine(context, engineSettings)
                                : null,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Apply Settings'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _restartEngine(
      BuildContext context, EngineSettingsProvider engineSettings) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Applying engine settings...'),
            ],
          ),
        ),
      );

      // Get the product provider to update the engine
      // final productProvider = Provider.of<ProductProvider>(context, listen: false);

      // Recreate the engine with new settings
      await PriceEngineService.recreateEngine(engineSettings);

      // Update the product provider with the new engine
      // Note: This would require adding a method to ProductProvider to update the engine
      // For now, we'll just show a success message and recommend restarting the app

      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        // Show success dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Settings Applied'),
            content: const Text(
                'Engine settings have been applied successfully.\n\n'
                'For best results, it\'s recommended to restart the app to ensure all components use the new settings.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        // Show error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Failed to Apply Settings'),
            content: Text('Failed to apply engine settings:\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _selectBrowserPath(
      BuildContext context, EngineSettingsProvider engineSettings) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['exe'],
      dialogTitle: 'Select Browser Executable',
    );

    if (result != null && result.files.single.path != null) {
      engineSettings.setbrowserPath(result.files.single.path!);
    }
  }

  Future<void> _selectWebdriverPath(
      BuildContext context, EngineSettingsProvider engineSettings) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['exe'],
      dialogTitle: 'Select Webdriver Executable',
    );

    if (result != null && result.files.single.path != null) {
      engineSettings.setWebdriverPath(result.files.single.path!);
    }
  }

  String _getThemeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System Default';
      case ThemeMode.light:
        return 'Light Mode';
      case ThemeMode.dark:
        return 'Dark Mode';
    }
  }

  String _getThemeModeDescription(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Follow system settings';
      case ThemeMode.light:
        return 'Always use light theme';
      case ThemeMode.dark:
        return 'Always use dark theme';
    }
  }

  String _formatRefreshInterval(int minutes) {
    if (minutes < 60) {
      return '$minutes minutes';
    } else {
      final hours = minutes ~/ 60;
      return hours == 1 ? '1 hour' : '$hours hours';
    }
  }

  String _capitalize(String text) {
    return text.isNotEmpty ? text[0].toUpperCase() + text.substring(1) : text;
  }
}
