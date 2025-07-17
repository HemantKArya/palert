import 'package:palert/src/rust/api/price_engine.dart';
import 'package:palert/providers/engine_settings_provider.dart';
import 'package:palert/providers/service_monitor_provider.dart';
import 'package:palert/services/notification_service.dart';
import 'package:flutter/material.dart';

class PriceEngineService {
  static PriceEngine? _currentEngine;
  static ServiceMonitorProvider? _serviceMonitor;

  static PriceEngine? get currentEngine => _currentEngine;
  static ServiceMonitorProvider? get serviceMonitor => _serviceMonitor;

  /// Creates a new price engine instance with the given settings
  static Future<PriceEngine?> createEngine(EngineSettingsProvider settings,
      [ServiceMonitorProvider? monitor]) async {
    // Dispose of the current engine if it exists
    await disposeCurrentEngine();

    try {
      // Create new engine with current settings
      _currentEngine = await PriceEngine.newInstance(
        port: settings.port,
        dbPath: settings.dbPath,
        browserPath: settings.browserPath,
        driverPath: settings.webdriverPath,
      );

      // Set up service monitoring
      _serviceMonitor = monitor;
      if (_serviceMonitor != null) {
        _serviceMonitor!.startMonitoring(_currentEngine);
      }

      return _currentEngine!;
    } catch (e) {
      await _handleEngineCreationError(e, settings);
      return null;
    }
  }

  /// Handles errors during engine creation
  static Future<void> _handleEngineCreationError(
      dynamic error, EngineSettingsProvider settings) async {
    String errorMessage = error.toString();

    if (errorMessage.contains('Failed to start chromedriver') ||
        errorMessage.contains('program not found') ||
        errorMessage.contains('Is it in your PATH?')) {
      await NotificationService.showServiceFailureNotification(
        reason: 'Chromedriver not found or failed to start',
        isRecoverable: true,
      );
    } else if (errorMessage.contains('port') && errorMessage.contains('busy')) {
      // Port conflict
      await NotificationService.showServiceFailureNotification(
        reason: 'Port ${settings.port} is already in use',
        isRecoverable: true,
      );
    } else {
      // Generic error
      await NotificationService.showServiceFailureNotification(
        reason: 'Engine initialization failed: $errorMessage',
        isRecoverable: false,
      );
    }
  }

  /// Recreates the price engine with updated settings
  static Future<PriceEngine?> recreateEngine(EngineSettingsProvider settings,
      [ServiceMonitorProvider? monitor]) async {
    return await createEngine(settings, monitor);
  }

  /// Manually restarts the browser service
  static Future<bool> restartBrowserService() async {
    if (_currentEngine == null) return false;

    try {
      // This would call the actual Rust function when implemented
      await NotificationService.showServiceNotification(
        title: 'Service Restart',
        message: 'Restarting browser service...',
      );

      // Simulate restart for now
      await Future.delayed(const Duration(seconds: 2));

      await NotificationService.showServiceRestartNotification(
        newPort: 9516,
        oldPort: 9515,
      );

      return true;
    } catch (e) {
      await NotificationService.showServiceFailureNotification(
        reason: 'Failed to restart service: $e',
        isRecoverable: false,
      );
      return false;
    }
  }

  /// Gets the current port being used by the service
  static Future<int> getCurrentPort() async {
    if (_currentEngine == null) return 0;

    try {
      // This would call the actual Rust function when implemented
      return 9515; // Placeholder
    } catch (e) {
      return 0;
    }
  }

  /// Checks service health
  static Future<ServiceStatus?> checkServiceHealth() async {
    if (_currentEngine == null) return null;

    try {
      // This would call the actual Rust function when implemented
      return ServiceStatus(
        isHealthy: true,
        currentPort: 9515,
        message: 'Service is healthy',
        lastCheck: DateTime.now().toIso8601String(),
        status: ServiceHealthStatus.healthy,
      );
    } catch (e) {
      return ServiceStatus(
        isHealthy: false,
        currentPort: 0,
        message: 'Failed to check service: $e',
        lastCheck: DateTime.now().toIso8601String(),
        status: ServiceHealthStatus.unknown,
      );
    }
  }

  /// Disposes the current engine and stops monitoring
  static Future<void> disposeCurrentEngine() async {
    if (_serviceMonitor != null) {
      _serviceMonitor!.stopMonitoring();
      _serviceMonitor = null;
    }

    if (_currentEngine != null) {
      try {
        await _currentEngine!.shutdown();
      } catch (e) {
        print('Error shutting down engine: $e');
      }
      _currentEngine = null;
    }
  }

  /// Shows a dialog to prompt user for correct webdriver path
  static Future<bool> promptForWebdriverPath(
      BuildContext context, EngineSettingsProvider settings) async {
    String newPath = settings.webdriverPath;
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final TextEditingController controller =
            TextEditingController(text: settings.webdriverPath);

        return AlertDialog(
          title: const Text('Chromedriver Not Found'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The chromedriver could not be started. Please provide the correct path to chromedriver.exe:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Chromedriver Path',
                  hintText: 'e.g., C:\\WebDrivers\\chromedriver.exe',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
                onChanged: (value) => newPath = value,
                onSubmitted: (value) {
                  newPath = value;
                  Navigator.of(context).pop(true);
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'Common locations:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...EngineSettingsProvider.getCommonWebdriverPaths()
                  .map((path) => Padding(
                        padding: const EdgeInsets.only(left: 8, top: 4),
                        child: InkWell(
                          onTap: () {
                            controller.text = path;
                            newPath = path;
                          },
                          child: Text(
                            '• $path',
                            style: const TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                newPath = controller.text.trim();
                Navigator.of(context).pop(true);
              },
              child: const Text('Try Again'),
            ),
          ],
        );
      },
    );

    if (result == true && newPath.isNotEmpty) {
      await settings.setWebdriverPath(newPath);
      return true;
    }
    return false;
  }
}
