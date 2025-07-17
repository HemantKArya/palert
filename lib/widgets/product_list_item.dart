import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:palert/providers/product_provider.dart';
import 'package:palert/src/rust/api/models.dart';

enum PriceChange { increased, decreased, same, unknown }

class ProductListItem extends StatelessWidget {
  final ProductRecord product;
  final bool isSelected;
  final VoidCallback onTap;

  const ProductListItem({
    super.key,
    required this.product,
    required this.isSelected,
    required this.onTap,
  });

  PriceChange getPriceChange() {
    if (product.priceHistory.length < 2) return PriceChange.unknown;
    final lastPrice = product.priceHistory.last.price;
    final prevPrice =
        product.priceHistory[product.priceHistory.length - 2].price;
    if (lastPrice > prevPrice) return PriceChange.increased;
    if (lastPrice < prevPrice) return PriceChange.decreased;
    return PriceChange.same;
  }

  // A small helper widget for the stock status "chip" for better readability
  Widget _buildStockStatusChip(bool inStock, ThemeData theme) {
    // Use theme-aware colors while maintaining semantic meaning
    final Color backgroundColor = inStock
        ? const Color(0xFF4CAF50)
            .withOpacity(0.1) // Material green with opacity
        : theme.colorScheme.errorContainer.withOpacity(0.5);
    final Color foregroundColor = inStock
        ? const Color(0xFF2E7D32) // Material green.shade800
        : theme.colorScheme.onErrorContainer;
    final IconData icon =
        inStock ? Icons.check_circle_outline : Icons.highlight_off_outlined;
    final String label = inStock ? 'In Stock' : 'Out of Stock';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: foregroundColor, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ProductProvider>();
    final theme = Theme.of(context);

    // Data extraction
    final latestPrice = product.priceHistory.isNotEmpty
        ? product.priceHistory.last.price
        : null;
    final inStock = product.priceHistory.isNotEmpty
        ? product.priceHistory.last.inStock
        : false;
    final change = getPriceChange();

    // Color mapping for price change
    final Map<PriceChange, Color> priceChangeColors = {
      PriceChange.increased: theme.colorScheme.error,
      PriceChange.decreased: const Color(0xFF2E7D32), // Material green.shade600
      PriceChange.same: theme.colorScheme.onSurface.withOpacity(0.6),
      PriceChange.unknown: Colors.transparent,
    };

    // Icon mapping for price change
    final Map<PriceChange, IconData> priceChangeIcons = {
      PriceChange.increased: Icons.trending_up,
      PriceChange.decreased: Icons.trending_down,
      PriceChange.same: Icons.trending_flat,
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: isSelected ? 8 : 2,
      shadowColor: isSelected
          ? theme.colorScheme.primary.withOpacity(0.3)
          : theme.colorScheme.shadow.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.2)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias, // Ensures InkWell ripple is clipped
      child: InkWell(
        onTap: onTap,
        hoverColor: theme.colorScheme.primary.withOpacity(0.04),
        splashColor: theme.colorScheme.primary.withOpacity(0.12),
        highlightColor: theme.colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top section: Title and Delete button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      product.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Using a more subtle delete button
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        color: theme.colorScheme.onSurface.withOpacity(0.6)),
                    iconSize: 22,
                    tooltip: 'Delete',
                    onPressed: () => provider.deleteProduct(product.id),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      hoverColor: theme.colorScheme.error.withOpacity(0.1),
                      // splashColor: theme.colorScheme.error.withOpacity(0.2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Bottom section: Price, Trend, and Stock Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Price and trend indicator
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Price',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.7)),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            latestPrice != null
                                ? NumberFormat.currency(
                                        locale: 'en_IN',
                                        symbol: '₹',
                                        decimalDigits: 0)
                                    .format(latestPrice)
                                : 'N/A',
                            style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(width: 8),
                          if (change != PriceChange.unknown)
                            Icon(
                              priceChangeIcons[change],
                              color: priceChangeColors[change],
                              size: 20,
                            ),
                        ],
                      ),
                    ],
                  ),

                  // Stock status chip
                  _buildStockStatusChip(inStock, theme),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
