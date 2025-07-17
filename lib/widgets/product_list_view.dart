import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:palert/providers/product_provider.dart';
import 'package:palert/widgets/product_details_view.dart';
import 'package:palert/widgets/product_list_item.dart';
import 'package:palert/src/rust/api/models.dart';

// Add sort modes for price sorting
enum SortMode { none, lowToHigh, highToLow }

// Change to StatefulWidget to support search UI and state
class ProductListView extends StatefulWidget {
  const ProductListView({super.key});

  @override
  _ProductListViewState createState() => _ProductListViewState();
}

class _ProductListViewState extends State<ProductListView> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<ProductRecord> _filteredProducts = [];
  SortMode _sortMode = SortMode.none; // current sort mode

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final provider = context.read<ProductProvider>();
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _filteredProducts = provider.products;
      });
    } else {
      final terms = query.split(RegExp(r"\s+"));
      setState(() {
        _filteredProducts = provider.products.where((p) {
          final keyData =
              ('${p.title} ${p.seller ?? ''} ${p.specifications} ${p.features.join(' ')} ${p.site}')
                  .toLowerCase();
          return terms.every((term) => keyData.contains(term));
        }).toList();
      });
    }
  }

  // Cycle through sort modes: none -> lowToHigh -> highToLow -> none
  void _cycleSortMode() {
    setState(() {
      _sortMode =
          SortMode.values[(_sortMode.index + 1) % SortMode.values.length];
    });
  }

  // Choose icon based on mode
  IconData _getSortIcon() {
    switch (_sortMode) {
      case SortMode.lowToHigh:
        return Icons.arrow_upward;
      case SortMode.highToLow:
        return Icons.arrow_downward;
      case SortMode.none:
        return Icons.sort;
    }
  }

  // Tooltip for accessibility
  String _getSortTooltip() {
    switch (_sortMode) {
      case SortMode.lowToHigh:
        return 'Sort: Price low→high';
      case SortMode.highToLow:
        return 'Sort: Price high→low';
      case SortMode.none:
        return 'Sort: Default';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    // Prepare list and apply sorting if needed
    List<ProductRecord> products =
        _isSearching ? List.of(_filteredProducts) : List.of(provider.products);
    if (_sortMode == SortMode.lowToHigh) {
      products.sort((a, b) {
        final pa = a.priceHistory.isNotEmpty ? a.priceHistory.last.price : 0;
        final pb = b.priceHistory.isNotEmpty ? b.priceHistory.last.price : 0;
        return pa.compareTo(pb);
      });
    } else if (_sortMode == SortMode.highToLow) {
      products.sort((a, b) {
        final pa = a.priceHistory.isNotEmpty ? a.priceHistory.last.price : 0;
        final pb = b.priceHistory.isNotEmpty ? b.priceHistory.last.price : 0;
        return pb.compareTo(pa);
      });
    }

    return Column(
      children: [
        // Search bar toggle and input
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isSearching
                ? Row(
                    key: const ValueKey('searchField'),
                    children: [
                      Expanded(
                        child: Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: Colors.transparent,
                              hintText: 'Search products...',
                              prefixIcon: Icon(Icons.search,
                                  size: 18,
                                  color: Theme.of(context).iconTheme.color),
                              suffixIcon: IconButton(
                                icon: Icon(Icons.close,
                                    size: 18,
                                    color: Theme.of(context).iconTheme.color),
                                splashRadius: 16,
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _isSearching = false;
                                  });
                                },
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 0, horizontal: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(
                                    color: Theme.of(context).dividerColor,
                                    width: 1),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Item count indicator in search mode
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2, size: 16),
                            const SizedBox(width: 4),
                            Text('${_filteredProducts.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  )
                : Row(
                    key: const ValueKey('searchButton'),
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Sort button on left
                      IconButton(
                        icon: Icon(_getSortIcon(), size: 18),
                        tooltip: _getSortTooltip(),
                        onPressed: _cycleSortMode,
                      ),
                      const SizedBox(width: 8),
                      // Item count indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2, size: 16),
                            const SizedBox(width: 4),
                            Text('${products.length}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Search button
                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () {
                          setState(() {
                            _isSearching = true;
                            _filteredProducts = provider.products;
                          });
                        },
                      ),
                    ],
                  ),
          ),
        ),
        // Product list
        Expanded(
          child: Stack(
            children: [
              ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return ProductListItem(
                    product: product,
                    isSelected: product.id == provider.selectedProduct?.id,
                    onTap: () {
                      if (MediaQuery.of(context).size.width <= 800) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Scaffold(
                              appBar: AppBar(
                                  title: Text(product.title,
                                      overflow: TextOverflow.ellipsis)),
                              body: ProductDetailView(product: product),
                            ),
                          ),
                        );
                      } else {
                        provider.selectProduct(product);
                      }
                    },
                  );
                },
              ),
              if (provider.state == AppState.loading)
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
