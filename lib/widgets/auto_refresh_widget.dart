import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:palert/providers/product_provider.dart';

class AutoRefreshWidget extends StatefulWidget {
  const AutoRefreshWidget({super.key});

  @override
  State<AutoRefreshWidget> createState() => _AutoRefreshWidgetState();
}

class _AutoRefreshWidgetState extends State<AutoRefreshWidget> {
  Timer? _uiUpdateTimer;

  @override
  void initState() {
    super.initState();
    // Update the UI every second to show countdown
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _uiUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductProvider>(
      builder: (context, provider, child) {
        return PopupMenuButton<String>(
          icon: Stack(
            children: [
              Icon(
                provider.isAutoRefreshEnabled
                    ? Icons.schedule
                    : Icons.schedule_outlined,
                color: provider.isAutoRefreshEnabled ? Colors.green : null,
              ),
              // Show a small indicator if auto-refresh is currently running
              if (provider.isAutoRefreshing)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          tooltip: provider.isAutoRefreshEnabled
              ? (provider.isAutoRefreshing
                  ? 'Auto-refresh in progress...'
                  : 'Auto-refresh: ${provider.refreshInterval.label}')
              : 'Configure auto-refresh',
          itemBuilder: (context) => [
            // Header with current status
            PopupMenuItem<String>(
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Auto Refresh',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (provider.isAutoRefreshEnabled) ...[
                    const SizedBox(height: 4),
                    if (provider.isAutoRefreshing) ...[
                      Row(
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Refreshing products...',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).primaryColor,
                                    ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        'Enabled: ${provider.refreshInterval.label}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.green,
                            ),
                      ),
                      if (provider.timeUntilNextRefresh != null)
                        Text(
                          'Next refresh in: ${_formatDuration(provider.timeUntilNextRefresh!)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                    if (provider.lastRefreshTime != null)
                      Text(
                        'Last refresh: ${_formatTime(provider.lastRefreshTime!)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ] else
                    Text(
                      'Disabled',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  const Divider(),
                ],
              ),
            ),

            // Toggle switch
            PopupMenuItem<String>(
              value: 'toggle',
              child: Row(
                children: [
                  Icon(
                    provider.isAutoRefreshEnabled
                        ? Icons.toggle_on
                        : Icons.toggle_off,
                    color: provider.isAutoRefreshEnabled
                        ? Colors.green
                        : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    provider.isAutoRefreshEnabled
                        ? 'Disable Auto-refresh'
                        : 'Enable Auto-refresh',
                  ),
                ],
              ),
            ),

            // Divider
            const PopupMenuDivider(),

            // Time interval options
            ...RefreshInterval.values.map((interval) {
              final isSelected = provider.refreshInterval == interval;
              return PopupMenuItem<String>(
                value: 'interval_${interval.name}',
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: isSelected ? Colors.blue : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      interval.label,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.blue : null,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          onSelected: (value) {
            if (value == 'toggle') {
              if (provider.isAutoRefreshEnabled) {
                provider.disableAutoRefresh();
              } else {
                provider.enableAutoRefresh(provider.refreshInterval);
              }
            } else if (value.startsWith('interval_')) {
              final intervalName = value.substring(9);
              final interval = RefreshInterval.values.firstWhere(
                (i) => i.name == intervalName,
              );

              if (provider.isAutoRefreshEnabled) {
                provider.updateRefreshInterval(interval);
              } else {
                provider.enableAutoRefresh(interval);
              }
            }
          },
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      final seconds = duration.inSeconds.remainder(60);
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (duration.inMinutes > 0) {
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds.remainder(60);
      return '${minutes}m ${seconds}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
