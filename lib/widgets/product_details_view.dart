import 'dart:convert';
import 'package:palert/widgets/price_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:palert/providers/product_provider.dart';
import 'package:palert/providers/status_provider.dart';
import 'package:palert/src/rust/api/models.dart';
import 'package:url_launcher/url_launcher.dart';

// We convert to a StatefulWidget to manage the state of the image carousel.
class ProductDetailView extends StatefulWidget {
  final ProductRecord product;

  const ProductDetailView({super.key, required this.product});

  @override
  State<ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends State<ProductDetailView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Define a breakpoint for our responsive layout
  static const double _responsiveBreakpoint = 768.0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      if (_pageController.hasClients && _pageController.page != null) {
        setState(() {
          _currentPage = _pageController.page!.round();
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.read<ProductProvider>();
    final latestPrice = widget.product.priceHistory.isNotEmpty
        ? widget.product.priceHistory.last
        : null;

    final bool isGlobalRefreshActive =
        provider.isRefreshingAll || provider.isAutoRefreshing;

    return Scaffold(
      // A slightly lighter background color for a softer look
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      body: RefreshIndicator(
        onRefresh: isGlobalRefreshActive
            ? () => Future.value() // No-op when global refresh is active
            : () => provider.refreshProduct(widget.product),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header Section ---
              _buildHeader(theme, latestPrice),
              const SizedBox(height: 24),

              // --- Price Section with Action Buttons ---
              if (latestPrice != null) ...[
                _buildPriceDisplay(theme, latestPrice, provider),
                const SizedBox(height: 24),
              ],

              // --- Responsive Section for Chart and Gallery ---
              _buildResponsiveChartAndGallery(context, theme),
              const SizedBox(height: 8), // Adjusted for card margin

              // --- Key Features Section ---
              if (widget.product.features.isNotEmpty)
                _buildSection(
                  title: 'KEY FEATURES',
                  child: _buildFeaturesList(theme),
                ),

              // --- Specifications Section ---
              if (widget.product.specifications.isNotEmpty)
                _buildSection(
                  title: 'SPECIFICATIONS',
                  child: _buildSpecifications(
                      theme, widget.product.specifications),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the main header with product title and stock status.
  Widget _buildHeader(ThemeData theme, PriceEntry? latestPrice) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.product.site.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                widget.product.title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        if (latestPrice != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: latestPrice.inStock
                    ? const Color(0xFF4CAF50).withOpacity(0.1) // Material green
                    : const Color(0xFFF44336).withOpacity(0.1), // Material red
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: latestPrice.inStock
                        ? const Color(0xFFA5D6A7) // Material green.shade200
                        : const Color(0xFFEF9A9A), // Material red.shade200
                    width: 1)),
            child: Text(
              latestPrice.inStock ? 'In Stock' : 'Out of Stock',
              style: TextStyle(
                color: latestPrice.inStock
                    ? const Color(0xFF2E7D32) // Material green.shade800
                    : const Color(0xFFC62828), // Material red.shade800
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  /// A clean, card-based display for the current price with action buttons.
  Widget _buildPriceDisplay(
      ThemeData theme, PriceEntry latestPrice, ProductProvider provider) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWideScreen = constraints.maxWidth > 400;

            if (isWideScreen) {
              // Wide screen: Show price and buttons in a row
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Price information on the left
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CURRENT PRICE',
                            style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer)),
                        const SizedBox(height: 4),
                        Text(
                          NumberFormat.currency(
                                  locale: 'en_IN',
                                  symbol: '₹ ',
                                  decimalDigits: 0)
                              .format(latestPrice.price),
                          style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary),
                        ),
                      ],
                    ),
                  ),
                  // Action buttons on the right
                  _buildActionButtonsRow(provider),
                ],
              );
            } else {
              // Narrow screen: Stack price and buttons vertically
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Price information at the top
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CURRENT PRICE',
                          style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer)),
                      const SizedBox(height: 4),
                      Text(
                        NumberFormat.currency(
                                locale: 'en_IN', symbol: '₹ ', decimalDigits: 0)
                            .format(latestPrice.price),
                        style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Action buttons at the bottom
                  _buildActionButtonsRow(provider),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  /// Builds a row of action buttons
  Widget _buildActionButtonsRow(ProductProvider provider) {
    final bool isRefreshing =
        provider.isRefreshingAll || provider.isAutoRefreshing;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActionButton(context,
            icon: Icons.refresh_rounded,
            tooltip: isRefreshing
                ? 'Cannot refresh while a global refresh is in progress'
                : 'Refresh product data',
            onPressed: isRefreshing
                ? null
                : () => provider.refreshProduct(widget.product)),
        const SizedBox(width: 8),
        _buildActionButton(context,
            icon: Icons.open_in_new_rounded,
            tooltip: 'Open in browser', onPressed: () async {
          final statusProvider = context.read<StatusProvider>();
          try {
            statusProvider.showInfo('Opening product in browser...');
            final uri = Uri.parse(widget.product.url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
              statusProvider.showSuccess('Product opened in browser');
            } else {
              statusProvider.showError('Could not open product URL');
            }
          } catch (e) {
            statusProvider.showError('Failed to open URL: $e');
          }
        }),
        const SizedBox(width: 8),
        _buildActionButton(context,
            icon: Icons.content_copy_rounded,
            tooltip: 'Copy product link', onPressed: () async {
          final statusProvider = context.read<StatusProvider>();
          try {
            await Clipboard.setData(ClipboardData(text: widget.product.url));
            statusProvider.showSuccess('Product link copied to clipboard');
          } catch (e) {
            statusProvider.showError('Failed to copy link: $e');
          }
        }),
        const SizedBox(width: 8),
        _buildActionButton(context,
            icon: Icons.delete_outline_rounded,
            tooltip: 'Delete product', onPressed: () async {
          print('Delete button pressed for product: ${widget.product.id}');
          try {
            await provider.deleteProduct(widget.product.id);
            print('Product deleted successfully');
            if (mounted && Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
          } catch (e) {
            print('Error deleting product: $e');
            if (mounted) {
              context
                  .read<StatusProvider>()
                  .showError('Error deleting product: $e');
            }
          }
        }),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context,
      {required IconData icon,
      required String tooltip,
      Future<void> Function()? onPressed}) {
    final theme = Theme.of(context);
    final bool isDisabled = onPressed == null;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8.0),
          child: Icon(
            icon,
            color: isDisabled
                ? theme.colorScheme.primary.withOpacity(0.5)
                : theme.colorScheme.primary,
            size: 20,
          ),
        ),
      ),
    );
  }

  /// Uses a LayoutBuilder to decide whether to show the chart and gallery
  /// in a Row (wide screens) or a Column (narrow screens).
  Widget _buildResponsiveChartAndGallery(
      BuildContext context, ThemeData theme) {
    // These are the widgets we want to lay out responsively.
    final chartWidget = _buildSection(
      title: 'PRICE HISTORY',
      child: SizedBox(
        height: 250 - 58, // Match the gallery height calculation
        child: widget.product.priceHistory.isNotEmpty
            ? PriceChart(priceHistory: widget.product.priceHistory)
            : const Center(child: Text("No price history yet.")),
      ),
    );

    final galleryWidget = widget.product.images.isNotEmpty
        ? _buildSection(
            title: 'GALLERY',
            child: _buildImageCarousel(theme),
          )
        : const SizedBox.shrink(); // Don't show if no images

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > _responsiveBreakpoint) {
          // WIDE SCREEN: Use a Row
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: chartWidget), // Give chart more space
              const SizedBox(width: 16),
              if (widget.product.images.isNotEmpty)
                Expanded(flex: 2, child: galleryWidget),
            ],
          );
        } else {
          // NARROW SCREEN: Use a Column
          return Column(
            children: [
              chartWidget,
              galleryWidget,
            ],
          );
        }
      },
    );
  }

  /// A generic wrapper to create a styled section Card with a title.
  Widget _buildSection({required String title, required Widget child}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: theme.colorScheme.surfaceContainer,
      clipBehavior: Clip.antiAlias, // Ensures child respects the border radius
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildImageCarousel(ThemeData theme) {
    return Column(
      children: [
        SizedBox(
          height: 250 - 58, // Match the price chart height minus padding/title
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: widget.product.images.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () => _showFullscreenImage(context, index),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: NetworkImage(widget.product.images[index]),
                          fit: BoxFit.contain,
                          onError: (exception, stackTrace) => Center(
                              child: Icon(Icons.image_not_supported_outlined,
                                  size: 48,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Navigation buttons - only show if there are multiple images
              if (widget.product.images.length > 1) ...[
                // Previous button
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.shadow.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: _currentPage > 0
                            ? () {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            : null,
                        icon: Icon(
                          Icons.chevron_left,
                          color: _currentPage > 0
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurface.withOpacity(0.3),
                        ),
                        iconSize: 20,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                    ),
                  ),
                ),
                // Next button
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.shadow.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: _currentPage <
                                widget.product.images.length - 1
                            ? () {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            : null,
                        icon: Icon(
                          Icons.chevron_right,
                          color: _currentPage < widget.product.images.length - 1
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurface.withOpacity(0.3),
                        ),
                        iconSize: 20,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Page indicators - only show if there are multiple images
        if (widget.product.images.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.product.images.length, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: _currentPage == index ? 24 : 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
      ],
    );
  }

  Widget _buildFeaturesList(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.product.features
          .map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(feature,
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(height: 1.4))),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildSpecifications(ThemeData theme, String specifications) {
    if (specifications.isEmpty) {
      return const SizedBox.shrink();
    }
    try {
      final specs = jsonDecode(specifications) as Map<String, dynamic>;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: specs.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    entry.key,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Text(
                    entry.value.toString(),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    } catch (e) {
      // Gracefully handle parsing errors
      return Text("Specifications could not be displayed.",
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.error));
    }
  }

  /// Shows fullscreen image viewer with navigation controls
  void _showFullscreenImage(BuildContext context, int initialIndex) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return _FullscreenImageViewer(
          images: widget.product.images,
          initialIndex: initialIndex,
        );
      },
    );
  }
}

/// Fullscreen image viewer with navigation controls
class _FullscreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullscreenImageViewer({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  late PageController _fullscreenController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _fullscreenController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _fullscreenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          // Main image viewer
          PageView.builder(
            controller: _fullscreenController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return Center(
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Image.network(
                    widget.images[index],
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: Colors.white,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          size: 80,
                          color: Colors.white54,
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),

          // Close button
          Positioned(
            top: 40,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(25),
              ),
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                padding: const EdgeInsets.all(12),
              ),
            ),
          ),

          // Navigation arrows (only show if there are multiple images)
          if (widget.images.length > 1) ...[
            // Previous button
            Positioned(
              left: 20,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: IconButton(
                    onPressed: _currentIndex > 0
                        ? () {
                            _fullscreenController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        : null,
                    icon: Icon(
                      Icons.chevron_left,
                      color: _currentIndex > 0 ? Colors.white : Colors.white38,
                      size: 32,
                    ),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ),
            ),

            // Next button
            Positioned(
              right: 20,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: IconButton(
                    onPressed: _currentIndex < widget.images.length - 1
                        ? () {
                            _fullscreenController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        : null,
                    icon: Icon(
                      Icons.chevron_right,
                      color: _currentIndex < widget.images.length - 1
                          ? Colors.white
                          : Colors.white38,
                      size: 32,
                    ),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ),
            ),
          ],

          // Image counter and info
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Page indicators
                  if (widget.images.length > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(widget.images.length, (index) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          height: 8,
                          width: _currentIndex == index ? 24 : 8,
                          decoration: BoxDecoration(
                            color: _currentIndex == index
                                ? Colors.white
                                : Colors.white38,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  const SizedBox(height: 12),
                  // Image counter
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentIndex + 1} of ${widget.images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
