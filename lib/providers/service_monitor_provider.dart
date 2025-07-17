import 'dart:async';
import 'package:flutter/material.dart';
import 'package:palert/src/rust/api/price_engine.dart';

enum ServiceHealthStatus {
  healthy,
  unhealthy,
  restarting,
  unknown,
}

class ServiceStatus {
  final bool isHealthy;
  final int currentPort;
  final String message;
  final String lastCheck;
  final ServiceHealthStatus status;

  ServiceStatus({
    required this.isHealthy,
    required this.currentPort,
    required this.message,
    required this.lastCheck,
    required this.status,
  });

  factory ServiceStatus.fromMap(Map<String, dynamic> map) {
    return ServiceStatus(
      isHealthy: map['is_healthy'] ?? false,
      currentPort: map['current_port'] ?? 0,
      message: map['message'] ?? '',
      lastCheck: map['last_check'] ?? '',
      status: map['is_healthy'] == true
          ? ServiceHealthStatus.healthy
          : ServiceHealthStatus.unhealthy,
    );
  }
}

class ServiceMonitorProvider extends ChangeNotifier {
  ServiceStatus? _currentStatus;
  Timer? _monitoringTimer;
  PriceEngine? _priceEngine;
  bool _isMonitoring = false;
  int _restartAttempts = 0;
  static const int maxRestartAttempts = 3;
  static const Duration monitoringInterval = Duration(seconds: 30);

  ServiceStatus? get currentStatus => _currentStatus;
  bool get isMonitoring => _isMonitoring;
  int get restartAttempts => _restartAttempts;

  /// Starts monitoring the service health
  void startMonitoring(PriceEngine? engine) {
    _priceEngine = engine;
    if (_priceEngine == null) return;

    _isMonitoring = true;
    _checkServiceHealth();

    _monitoringTimer?.cancel();
    _monitoringTimer = Timer.periodic(monitoringInterval, (timer) {
      _checkServiceHealth();
    });

    notifyListeners();
  }

  /// Stops monitoring the service
  void stopMonitoring() {
    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    notifyListeners();
  }

  /// Manually checks service health
  Future<void> checkServiceHealthManually() async {
    await _checkServiceHealth();
  }

  /// Internal method to check service health
  Future<void> _checkServiceHealth() async {
    if (_priceEngine == null) return;

    try {
      // This would call the Rust function through FFI
      // For now, we'll simulate the call
      final statusMap = await _simulateServiceCheck();

      final newStatus = ServiceStatus.fromMap(statusMap);

      if (_currentStatus?.isHealthy != newStatus.isHealthy) {
        _handleHealthStatusChange(newStatus);
      }

      _currentStatus = newStatus;
      notifyListeners();
    } catch (e) {
      _currentStatus = ServiceStatus(
        isHealthy: false,
        currentPort: _currentStatus?.currentPort ?? 0,
        message: 'Failed to check service health: $e',
        lastCheck: DateTime.now().toIso8601String(),
        status: ServiceHealthStatus.unknown,
      );
      notifyListeners();
    }
  }

  /// Handles changes in health status
  void _handleHealthStatusChange(ServiceStatus newStatus) {
    if (!newStatus.isHealthy && _currentStatus?.isHealthy == true) {
      // Service became unhealthy
      _onServiceUnhealthy();
    } else if (newStatus.isHealthy && _currentStatus?.isHealthy == false) {
      // Service became healthy
      _onServiceHealthy();
      _restartAttempts = 0; // Reset restart attempts
    }
  }

  /// Called when service becomes unhealthy
  void _onServiceUnhealthy() {
    if (_restartAttempts < maxRestartAttempts) {
      _attemptServiceRestart();
    }
  }

  /// Called when service becomes healthy
  void _onServiceHealthy() {
    // Could send a recovery notification
  }

  /// Attempts to restart the service
  Future<void> _attemptServiceRestart() async {
    if (_priceEngine == null) return;

    _restartAttempts++;

    _currentStatus = ServiceStatus(
      isHealthy: false,
      currentPort: _currentStatus?.currentPort ?? 0,
      message:
          'Attempting service restart (${_restartAttempts}/${maxRestartAttempts})...',
      lastCheck: DateTime.now().toIso8601String(),
      status: ServiceHealthStatus.restarting,
    );
    notifyListeners();

    try {
      // This would call the Rust restart function
      final result = await _simulateServiceRestart();

      _currentStatus = ServiceStatus(
        isHealthy: true,
        currentPort: _currentStatus?.currentPort ?? 0,
        message: result,
        lastCheck: DateTime.now().toIso8601String(),
        status: ServiceHealthStatus.healthy,
      );
    } catch (e) {
      _currentStatus = ServiceStatus(
        isHealthy: false,
        currentPort: _currentStatus?.currentPort ?? 0,
        message: 'Service restart failed: $e',
        lastCheck: DateTime.now().toIso8601String(),
        status: ServiceHealthStatus.unhealthy,
      );

      if (_restartAttempts >= maxRestartAttempts) {
        _currentStatus = _currentStatus!.copyWith(
          message:
              'Service restart failed after ${maxRestartAttempts} attempts. Manual intervention required.',
        );
      }
    }

    notifyListeners();
  }

  /// Manually trigger a service restart
  Future<void> manualServiceRestart() async {
    _restartAttempts = 0; // Reset attempts for manual restart
    await _attemptServiceRestart();
  }

  /// Gets the current port
  Future<int> getCurrentPort() async {
    if (_priceEngine == null) return 0;

    try {
      // This would call the Rust function to get current port
      return await _simulateGetCurrentPort();
    } catch (e) {
      return 0;
    }
  }

  // Integration with Rust browser service manager
  Future<Map<String, dynamic>> _simulateServiceCheck() async {
    if (_priceEngine == null) {
      return {
        'is_healthy': false,
        'current_port': 0,
        'message': 'Price engine not initialized',
        'last_check': DateTime.now().toIso8601String(),
      };
    }

    try {
      final status = await _priceEngine!.checkServiceStatus();

      return {
        'is_healthy': status.isHealthy,
        'current_port': status.currentPort,
        'message': status.message,
        'last_check': status.lastCheck,
      };
    } catch (e) {
      return {
        'is_healthy': false,
        'current_port': 0,
        'message': 'Failed to check service: $e',
        'last_check': DateTime.now().toIso8601String(),
      };
    }
  }

  Future<String> _simulateServiceRestart() async {
    if (_priceEngine == null) {
      throw Exception('Price engine not initialized');
    }

    try {
      final status = await _priceEngine!.restartBrowserService();

      if (status.isHealthy) {
        return 'Service restarted successfully on port ${status.port}';
      } else {
        throw Exception(status.errorMessage ?? 'Unknown error');
      }
    } catch (e) {
      throw Exception('Service restart failed: $e');
    }
  }

  Future<int> _simulateGetCurrentPort() async {
    if (_priceEngine == null) return 0;

    try {
      return await _priceEngine!.getCurrentPort();
    } catch (e) {
      return 0;
    }
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}

extension ServiceStatusExtension on ServiceStatus {
  ServiceStatus copyWith({
    bool? isHealthy,
    int? currentPort,
    String? message,
    String? lastCheck,
    ServiceHealthStatus? status,
  }) {
    return ServiceStatus(
      isHealthy: isHealthy ?? this.isHealthy,
      currentPort: currentPort ?? this.currentPort,
      message: message ?? this.message,
      lastCheck: lastCheck ?? this.lastCheck,
      status: status ?? this.status,
    );
  }

  Color get statusColor {
    switch (status) {
      case ServiceHealthStatus.healthy:
        return Colors.green;
      case ServiceHealthStatus.unhealthy:
        return Colors.red;
      case ServiceHealthStatus.restarting:
        return Colors.orange;
      case ServiceHealthStatus.unknown:
        return Colors.grey;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case ServiceHealthStatus.healthy:
        return Icons.check_circle;
      case ServiceHealthStatus.unhealthy:
        return Icons.error;
      case ServiceHealthStatus.restarting:
        return Icons.refresh;
      case ServiceHealthStatus.unknown:
        return Icons.help;
    }
  }
}
