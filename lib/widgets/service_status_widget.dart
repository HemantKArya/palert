import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:palert/providers/service_monitor_provider.dart';
import 'package:palert/services/price_engine_service.dart';

class ServiceStatusWidget extends StatelessWidget {
  final bool isCompact;

  const ServiceStatusWidget({
    super.key,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ServiceMonitorProvider>(
      builder: (context, serviceMonitor, child) {
        final status = serviceMonitor.currentStatus;

        if (status == null) {
          return isCompact
              ? _buildCompactWidget(context, null)
              : _buildDetailedWidget(context, null);
        }

        return isCompact
            ? _buildCompactWidget(context, status)
            : _buildDetailedWidget(context, status);
      },
    );
  }

  Widget _buildCompactWidget(BuildContext context, ServiceStatus? status) {
    if (status == null) {
      return const Icon(
        Icons.help_outline,
        color: Colors.grey,
        size: 16,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          status.statusIcon,
          color: status.statusColor,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          'Port ${status.currentPort}',
          style: TextStyle(
            fontSize: 12,
            color: status.statusColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedWidget(BuildContext context, ServiceStatus? status) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.web,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Browser Service Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                if (status != null) ...[
                  Icon(
                    status.statusIcon,
                    color: status.statusColor,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    status.isHealthy ? 'Healthy' : 'Unhealthy',
                    style: TextStyle(
                      color: status.statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            if (status != null) ...[
              _buildStatusRow('Current Port', '${status.currentPort}'),
              _buildStatusRow('Status', status.message),
              _buildStatusRow('Last Check', _formatTimestamp(status.lastCheck)),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _refreshStatus(context),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh'),
                  ),
                  const SizedBox(width: 8),
                  if (!status.isHealthy)
                    ElevatedButton.icon(
                      onPressed: () => _restartService(context),
                      icon: const Icon(Icons.restart_alt, size: 16),
                      label: const Text('Restart'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
            ] else ...[
              const Text('Service status unknown'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _refreshStatus(context),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Check Status'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inSeconds < 60) {
        return '${difference.inSeconds}s ago';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else {
        return '${difference.inHours}h ago';
      }
    } catch (e) {
      return timestamp;
    }
  }

  void _refreshStatus(BuildContext context) {
    final serviceMonitor =
        Provider.of<ServiceMonitorProvider>(context, listen: false);
    serviceMonitor.checkServiceHealthManually();
  }

  void _restartService(BuildContext context) async {
    final serviceMonitor =
        Provider.of<ServiceMonitorProvider>(context, listen: false);

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Restarting browser service...'),
          ],
        ),
      ),
    );

    try {
      final success = await PriceEngineService.restartBrowserService();

      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Browser service restarted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh status after restart
          serviceMonitor.checkServiceHealthManually();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to restart browser service'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error restarting service: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
