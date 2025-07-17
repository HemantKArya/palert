import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:palert/src/rust/api/models.dart';

// (Paste the LivePriceDotPainter class here if you're keeping it in one file)

// STEP 1: Convert to StatefulWidget
class PriceChart extends StatefulWidget {
  final List<PriceEntry> priceHistory;
  const PriceChart({super.key, required this.priceHistory});

  @override
  State<PriceChart> createState() => _PriceChartState();
}

// Add SingleTickerProviderStateMixin for the animation controller
class _PriceChartState extends State<PriceChart>
    with SingleTickerProviderStateMixin {
  // STEP 2: Create and manage the AnimationController
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Duration of one ripple cycle
    )..repeat(); // Make the animation loop continuously
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    // Use widget.priceHistory to access the data from the StatefulWidget
    List<FlSpot> spots = [];
    if (widget.priceHistory.isNotEmpty) {
      for (var i = 0; i < widget.priceHistory.length; i++) {
        spots
            .add(FlSpot(i.toDouble(), widget.priceHistory[i].price.toDouble()));
      }
    }

    // Handle empty data case
    if (spots.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No price data available',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Price history will appear here once data is collected',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final double minPrice = spots.map((e) => e.y).reduce(min);
    final double maxPrice = spots.map((e) => e.y).reduce(max);

    bool isSinglePoint = spots.length < 2;

    // Calculate a safe horizontal interval, ensuring it's never zero
    final double priceRange = maxPrice - minPrice;
    final double horizontalInterval = priceRange > 0
        ? priceRange / 4
        : maxPrice > 0
            ? maxPrice / 4
            : 1000;

    // Calculate smart intervals for bottom axis to prevent overlapping
    final int maxBottomLabels = 6; // Maximum number of labels on bottom axis
    final double bottomInterval = spots.length > maxBottomLabels
        ? (spots.length - 1) / (maxBottomLabels - 1)
        : 1;

    // Calculate smart intervals for left axis to prevent overlapping
    final int maxLeftLabels = 5; // Maximum number of labels on left axis
    final double leftInterval =
        priceRange > 0 ? priceRange / maxLeftLabels : horizontalInterval;

    // STEP 3: Wrap the chart in an AnimatedBuilder
    // This tells Flutter to rebuild the chart on every animation frame
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, _) {
        return LineChart(
          LineChartData(
            // Add subtle grid for better readability
            gridData: FlGridData(
              show: priceRange >
                  0, // Only show grid if there's a meaningful price range
              drawHorizontalLine: true,
              drawVerticalLine: false,
              horizontalInterval: leftInterval, // Use smart interval for grid
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: theme.colorScheme.outline.withOpacity(0.1),
                  strokeWidth: 1,
                );
              },
            ),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: isSinglePoint ? 1 : (spots.length - 1).toDouble(),
            minY: priceRange > 0
                ? minPrice - (priceRange * 0.1) // Add 10% padding below
                : (maxPrice > 0 ? maxPrice * 0.85 : 0),
            maxY: priceRange > 0
                ? maxPrice + (priceRange * 0.1) // Add 10% padding above
                : (maxPrice > 0 ? maxPrice * 1.15 : 1000),
            titlesData: FlTitlesData(
              show: true,
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles:
                      true, // Always show Y-axis titles when we have data
                  reservedSize:
                      60, // Increased reserved size for better spacing
                  interval: leftInterval, // Use smart interval
                  getTitlesWidget: (value, meta) {
                    // For single point or very small range, show the actual price
                    if (priceRange < maxPrice * 0.01) {
                      if ((value - maxPrice).abs() < leftInterval * 0.1) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            NumberFormat.compactSimpleCurrency(
                                    locale: 'en_IN', decimalDigits: 0)
                                .format(maxPrice),
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        );
                      }
                      return const SizedBox();
                    }

                    // Don't show labels at the very top and bottom to avoid crowding
                    if (value >= meta.max * 0.95 || value <= meta.min * 1.05) {
                      return const SizedBox();
                    }

                    // Skip if the value is very close to min or max price
                    if ((value - minPrice).abs() < priceRange * 0.05 ||
                        (value - maxPrice).abs() < priceRange * 0.05) {
                      return const SizedBox();
                    }

                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text(
                        NumberFormat.compactSimpleCurrency(
                                locale: 'en_IN', decimalDigits: 0)
                            .format(value),
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 35,
                  interval: bottomInterval, // Use smart interval
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= widget.priceHistory.length) {
                      return const SizedBox();
                    }

                    // Show labels only at calculated intervals to prevent overlap
                    if (spots.length > maxBottomLabels) {
                      // For many points, show only evenly spaced labels
                      final shouldShow = index % bottomInterval.ceil() == 0 ||
                          index == 0 ||
                          index == widget.priceHistory.length - 1;
                      if (!shouldShow) return const SizedBox();
                    }

                    final date =
                        DateTime.parse(widget.priceHistory[index].timestamp)
                            .toLocal();

                    // Adaptive date format based on data density and time range
                    String dateFormat;
                    if (spots.length > 20) {
                      dateFormat = 'd/M'; // Very short for many points
                    } else if (spots.length > 10) {
                      dateFormat = 'd MMM'; // Short format
                    } else {
                      // Check if we have data spanning multiple months
                      final firstDate =
                          DateTime.parse(widget.priceHistory.first.timestamp);
                      final lastDate =
                          DateTime.parse(widget.priceHistory.last.timestamp);
                      final daysDiff = lastDate.difference(firstDate).inDays;

                      if (daysDiff > 60) {
                        dateFormat = 'd MMM'; // Show month for long ranges
                      } else if (daysDiff > 7) {
                        dateFormat = 'd MMM'; // Show month and day
                      } else {
                        dateFormat = 'E d'; // Show weekday for short ranges
                      }
                    }

                    return SideTitleWidget(
                      meta: meta,
                      space: 8.0,
                      child: Text(
                        DateFormat(dateFormat).format(date),
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              handleBuiltInTouches: true,
              touchSpotThreshold: 20, // Make touch area more generous
              getTouchedSpotIndicator:
                  (LineChartBarData barData, List<int> spotIndexes) {
                return spotIndexes.map((spotIndex) {
                  return TouchedSpotIndicatorData(
                    FlLine(
                      color: primaryColor.withOpacity(0.6),
                      strokeWidth: 2,
                      dashArray: [3, 3], // Add subtle dash pattern
                    ),
                    FlDotData(
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 6,
                          color: primaryColor,
                          strokeWidth: 3,
                          strokeColor: theme.colorScheme.surface,
                        );
                      },
                    ),
                  );
                }).toList();
              },
              touchTooltipData: LineTouchTooltipData(
                fitInsideHorizontally: true,
                tooltipHorizontalAlignment: FLHorizontalAlignment.center,
                tooltipMargin: 8,
                tooltipPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                tooltipBorder: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.12),
                  width: 0.5,
                ),
                getTooltipColor: (touchedSpot) {
                  // Use theme-aware background color with subtle transparency
                  return theme.brightness == Brightness.dark
                      ? theme.colorScheme.surface.withOpacity(0.98)
                      : theme.colorScheme.surface.withOpacity(0.95);
                },
                getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                  return touchedBarSpots.map((barSpot) {
                    final flSpot = barSpot.bar.spots[barSpot.spotIndex];
                    final date = DateTime.parse(
                            widget.priceHistory[flSpot.x.toInt()].timestamp)
                        .toLocal();
                    return LineTooltipItem(
                      '₹${NumberFormat('#,##,###').format(flSpot.y.toInt())}\n',
                      TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        letterSpacing: 0.1,
                      ),
                      children: [
                        TextSpan(
                          text: DateFormat('d MMM yyyy, hh:mm a').format(date),
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.05,
                          ),
                        ),
                      ],
                    );
                  }).toList();
                },
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                isStrokeCapRound: true,
                barWidth: 2.5,
                color: primaryColor,
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(
                          theme.brightness == Brightness.dark ? 0.15 : 0.25),
                      primaryColor.withOpacity(0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.8],
                  ),
                ),
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    // Use our custom painter for the last dot with enhanced styling
                    if (isSinglePoint || index == barData.spots.length - 1) {
                      return LivePriceDotPainter(
                        animation: _animationController,
                        radius: 5,
                        color: primaryColor,
                        strokeWidth: 2.5,
                        strokeColor: theme.colorScheme.surface,
                      );
                    }
                    return FlDotCirclePainter(radius: 0); // Hide other dots
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A custom dot painter for fl_chart that draws a central dot
/// and an animated, expanding ripple circle.
class LivePriceDotPainter extends FlDotPainter {
  final Animation<double> animation;
  final double radius;
  final Color color;
  final double strokeWidth;
  final Color strokeColor;

  LivePriceDotPainter({
    required this.animation,
    this.radius = 6,
    required this.color,
    this.strokeWidth = 2,
    required this.strokeColor,
  });

  @override
  void draw(Canvas canvas, FlSpot spot, Offset center) {
    // --- Draw the ripple ---
    // The ripple expands from its base size to double that size.
    final rippleRadius = radius + (radius * 2 * animation.value);
    // The ripple fades out as it expands.
    final rippleOpacity = 1.0 - animation.value;

    final ripplePaint = Paint()
      ..color = color
          .withOpacity(rippleOpacity.clamp(0.0, 1.0)) // Ensure opacity is valid
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, rippleRadius, ripplePaint);

    // --- Draw the central dot (on top of the ripple) ---
    // First, draw the stroke (the background circle)
    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius + strokeWidth, strokePaint);

    // Then, draw the main filled dot
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, fillPaint);
  }

  @override
  Size getSize(FlSpot spot) {
    // The size of the touchable area for the dot
    return Size(radius * 5, radius * 5);
  }

  // FIX: Implement the 'lerp' method.
  // This is used by fl_chart to animate between two painters.
  // For our ripple effect, which is driven by an external AnimationController,
  // we can simply return the 'to' painter (the destination state).
  @override
  FlDotPainter lerp(FlDotPainter a, FlDotPainter b, double t) {
    if (b is LivePriceDotPainter) {
      return b; // We use our own animation, so no need to interpolate here.
    }
    return b;
  }

  // FIX: Implement the 'mainColor' getter.
  // This should return the primary color of the dot.
  @override
  Color get mainColor => color;

  // FIX: Implement the 'props' getter for Equatable.
  // This helps fl_chart determine if the painter has changed and needs a redraw.
  @override
  List<Object?> get props => [
        // We exclude 'animation' from props because it changes every frame.
        // If we included it, Equatable would think the painter is always "different",
        // which is not its intended use here. The AnimatedBuilder handles the redraws.
        radius,
        color,
        strokeWidth,
        strokeColor,
      ];

  // The old '==' and 'hashCode' can now be removed because Equatable handles them
  // based on the 'props' list.
}
