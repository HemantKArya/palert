import 'dart:async';
import 'package:flutter/material.dart';

enum StatusType {
  info,
  success,
  warning,
  error,
  loading,
}

class StatusMessage {
  final String id;
  final String message;
  final StatusType type;
  final DateTime timestamp;
  final Duration? duration;
  final bool persistent;

  StatusMessage({
    required this.id,
    required this.message,
    required this.type,
    required this.timestamp,
    this.duration,
    this.persistent = false,
  });

  StatusMessage copyWith({
    String? id,
    String? message,
    StatusType? type,
    DateTime? timestamp,
    Duration? duration,
    bool? persistent,
  }) {
    return StatusMessage(
      id: id ?? this.id,
      message: message ?? this.message,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      duration: duration ?? this.duration,
      persistent: persistent ?? this.persistent,
    );
  }
}

class StatusProvider extends ChangeNotifier {
  final List<StatusMessage> _statusHistory = [];
  StatusMessage? _currentStatus;
  Timer? _autoHideTimer;

  StatusMessage? get currentStatus => _currentStatus;
  List<StatusMessage> get statusHistory => List.unmodifiable(_statusHistory);

  static const Duration _defaultDuration = Duration(seconds: 3);
  static const int _maxHistorySize = 50;

  void showStatus({
    required String message,
    StatusType type = StatusType.info,
    Duration? duration,
    bool persistent = false,
    String? id,
  }) {
    final statusId = id ?? DateTime.now().millisecondsSinceEpoch.toString();

    final status = StatusMessage(
      id: statusId,
      message: message,
      type: type,
      timestamp: DateTime.now(),
      duration: duration ?? (persistent ? null : _defaultDuration),
      persistent: persistent,
    );

    _setCurrentStatus(status);
    _addToHistory(status);
  }

  void showLoading(String message, {String? id}) {
    showStatus(
      message: message,
      type: StatusType.loading,
      persistent: true,
      id: id,
    );
  }

  void showSuccess(String message, {Duration? duration, String? id}) {
    showStatus(
      message: message,
      type: StatusType.success,
      duration: duration,
      id: id,
    );
  }

  void showError(String message, {Duration? duration, String? id}) {
    showStatus(
      message: message,
      type: StatusType.error,
      duration: duration ?? const Duration(seconds: 5),
      id: id,
    );
  }

  void showWarning(String message, {Duration? duration, String? id}) {
    showStatus(
      message: message,
      type: StatusType.warning,
      duration: duration,
      id: id,
    );
  }

  void showInfo(String message, {Duration? duration, String? id}) {
    showStatus(
      message: message,
      type: StatusType.info,
      duration: duration,
      id: id,
    );
  }

  void updateStatus({
    required String id,
    String? message,
    StatusType? type,
    bool? persistent,
  }) {
    if (_currentStatus?.id == id) {
      _currentStatus = _currentStatus!.copyWith(
        message: message,
        type: type,
        persistent: persistent,
      );
      notifyListeners();
    }
  }

  void hideStatus({String? id}) {
    if (id == null || _currentStatus?.id == id) {
      _currentStatus = null;
      _autoHideTimer?.cancel();
      _autoHideTimer = null;
      notifyListeners();
    }
  }

  void clearAll() {
    _currentStatus = null;
    _statusHistory.clear();
    _autoHideTimer?.cancel();
    _autoHideTimer = null;
    notifyListeners();
  }

  void _setCurrentStatus(StatusMessage status) {
    _currentStatus = status;
    _autoHideTimer?.cancel();

    if (!status.persistent && status.duration != null) {
      _autoHideTimer = Timer(status.duration!, () {
        if (_currentStatus?.id == status.id) {
          hideStatus();
        }
      });
    }

    notifyListeners();
  }

  void _addToHistory(StatusMessage status) {
    _statusHistory.insert(0, status);

    // Keep history size manageable
    if (_statusHistory.length > _maxHistorySize) {
      _statusHistory.removeRange(_maxHistorySize, _statusHistory.length);
    }
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    super.dispose();
  }
}
