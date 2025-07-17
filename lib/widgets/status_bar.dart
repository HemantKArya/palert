import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:palert/providers/status_provider.dart';
import 'package:palert/widgets/service_status_widget.dart';

class StatusBar extends StatefulWidget {
  const StatusBar({super.key});

  @override
  State<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<StatusBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StatusProvider>(
      builder: (context, statusProvider, child) {
        final currentStatus = statusProvider.currentStatus;

        if (currentStatus == null) {
          if (_animationController.isCompleted) {
            _animationController.reverse();
          }
          return const SizedBox.shrink();
        }

        if (!_animationController.isCompleted) {
          _animationController.forward();
        }

        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _slideAnimation.value * 100),
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: _buildStatusContent(context, currentStatus),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusContent(BuildContext context, StatusMessage status) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(theme, status.type);
    final statusIcon = _getStatusIcon(status.type);

    return Material(
      color: theme.colorScheme.surface,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          border: Border(
            top: BorderSide(
              color: statusColor.withOpacity(0.3),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              // Status icon with animation for loading
              SizedBox(
                width: 20,
                height: 20,
                child: status.type == StatusType.loading
                    ? _buildLoadingIndicator(statusColor)
                    : Icon(
                        statusIcon,
                        color: statusColor,
                        size: 16,
                      ),
              ),
              const SizedBox(width: 12),

              // Status message
              Expanded(
                child: Text(
                  status.message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Timestamp
              Text(
                _formatTimestamp(status.timestamp),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: statusColor.withOpacity(0.7),
                  fontSize: 10,
                ),
              ),

              // Service status indicator
              const SizedBox(width: 8),
              const ServiceStatusWidget(isCompact: true),

              // Close button for persistent messages
              if (status.persistent) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    context.read<StatusProvider>().hideStatus(id: status.id);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      color: statusColor.withOpacity(0.7),
                      size: 14,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(Color color) {
    return SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }

  Color _getStatusColor(ThemeData theme, StatusType type) {
    switch (type) {
      case StatusType.success:
        return Colors.green.shade700;
      case StatusType.error:
        return Colors.red.shade700;
      case StatusType.warning:
        return Colors.orange.shade700;
      case StatusType.loading:
        return theme.colorScheme.primary;
      case StatusType.info:
        return theme.colorScheme.onSurfaceVariant;
    }
  }

  IconData _getStatusIcon(StatusType type) {
    switch (type) {
      case StatusType.success:
        return Icons.check_circle_outline;
      case StatusType.error:
        return Icons.error_outline;
      case StatusType.warning:
        return Icons.warning_amber_outlined;
      case StatusType.loading:
        return Icons.refresh;
      case StatusType.info:
        return Icons.info_outline;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

/// A floating status bar that can be positioned anywhere in the widget tree
class FloatingStatusBar extends StatelessWidget {
  final Widget child;
  final EdgeInsets? margin;

  const FloatingStatusBar({
    super.key,
    required this.child,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            margin: margin ?? const EdgeInsets.all(16),
            child: const StatusBar(),
          ),
        ),
      ],
    );
  }
}

/// A status history dialog to show all previous status messages
class StatusHistoryDialog extends StatelessWidget {
  const StatusHistoryDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.history,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Status History',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),

            // History list
            Expanded(
              child: Consumer<StatusProvider>(
                builder: (context, statusProvider, child) {
                  final history = statusProvider.statusHistory;

                  if (history.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history_outlined,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No status history yet',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: history.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final status = history[index];
                      final statusColor = _getStatusColor(theme, status.type);
                      final statusIcon = _getStatusIcon(status.type);

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: statusColor.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              statusIcon,
                              color: statusColor,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    status.message,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: statusColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDetailedTimestamp(status.timestamp),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(ThemeData theme, StatusType type) {
    switch (type) {
      case StatusType.success:
        return Colors.green.shade700;
      case StatusType.error:
        return Colors.red.shade700;
      case StatusType.warning:
        return Colors.orange.shade700;
      case StatusType.loading:
        return theme.colorScheme.primary;
      case StatusType.info:
        return theme.colorScheme.onSurfaceVariant;
    }
  }

  IconData _getStatusIcon(StatusType type) {
    switch (type) {
      case StatusType.success:
        return Icons.check_circle_outline;
      case StatusType.error:
        return Icons.error_outline;
      case StatusType.warning:
        return Icons.warning_amber_outlined;
      case StatusType.loading:
        return Icons.refresh;
      case StatusType.info:
        return Icons.info_outline;
    }
  }

  String _formatDetailedTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minute${difference.inMinutes != 1 ? 's' : ''} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours != 1 ? 's' : ''} ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year} at ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}
