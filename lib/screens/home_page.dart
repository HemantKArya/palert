import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:palert/providers/product_provider.dart';
import 'package:palert/providers/engine_settings_provider.dart';
import 'package:palert/src/rust/api/models.dart';
import 'package:palert/widgets/auto_refresh_widget.dart';
import 'package:palert/widgets/product_details_view.dart';
import 'package:palert/widgets/product_list_view.dart';
import 'package:palert/widgets/status_bar.dart';
import 'package:palert/screens/settings_page.dart';
import 'package:palert/services/price_engine_service.dart';

enum EngineInitializationState {
  initializing,
  success,
  failed,
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _urlController = TextEditingController();

  // New state to track engine initialization more granularly
  EngineInitializationState _engineInitializationState =
      EngineInitializationState.initializing;

  @override
  void initState() {
    super.initState();
    // Set the context for ProductProvider after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().setContext(context);
      _initializeEngine();
    });
  }

  Future<void> _initializeEngine() async {
    // Use the new state enum instead of a boolean flag
    if (_engineInitializationState == EngineInitializationState.initializing &&
        mounted) {
      // To avoid re-triggering initialization if it's already running
    } else {
      setState(() {
        _engineInitializationState = EngineInitializationState.initializing;
      });
    }

    final productProvider = context.read<ProductProvider>();
    final engineSettings = context.read<EngineSettingsProvider>();

    // Check if engine is already initialized
    if (productProvider.hasEngine) {
      if (mounted) {
        setState(() {
          _engineInitializationState = EngineInitializationState.success;
        });
      }
      return;
    }

    // Try to initialize the engine
    try {
      final engine = await PriceEngineService.createEngine(engineSettings);
      if (engine != null && mounted) {
        productProvider.setEngine(engine);
        setState(() {
          _engineInitializationState = EngineInitializationState.success;
        });
      } else if (mounted) {
        // Engine creation failed (e.g., chromedriver issue)
        setState(() {
          _engineInitializationState = EngineInitializationState.failed;
        });
      }
    } catch (e) {
      // Handle other unexpected errors during initialization
      if (mounted) {
        setState(() {
          _engineInitializationState = EngineInitializationState.failed;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize price engine: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _showAddUrlDialog(BuildContext context) {
    // Get the provider ONCE outside the builder and without listening.
    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);

    // Check if engine is available
    if (!productProvider.hasEngine) {
      _showEngineNotInitializedDialog(context);
      return;
    }

    // Check if a global refresh is in progress
    if (productProvider.isRefreshingAll || productProvider.isAutoRefreshing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Please wait for the current refresh operation to complete before adding a new product.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Add Product URL'),
          content: TextField(
            controller: _urlController,
            decoration: const InputDecoration(hintText: "https://..."),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                _urlController.clear();
                Navigator.of(dialogContext).pop();
              },
            ),
            FilledButton(
              child: const Text('Track'),
              onPressed: () {
                // 1. Validate and grab the URL from the controller.
                final url = _urlController.text.trim();
                if (url.isEmpty) return;

                // 2. IMPORTANT: Close the dialog *before* the async operation.
                // This prevents the 'deactivated widget' error. The main UI will now
                // show a loading indicator because the provider state will change.
                Navigator.of(dialogContext).pop();
                _urlController.clear();

                // 3. Start the background task. The provider handles the loading state.
                // We use `.then()` to handle the result (e.g., show an error)
                // without making the button's onPressed async.
                productProvider.addProduct(url).then((success) {
                  // The 'mounted' check is crucial here to ensure the HomePage widget
                  // is still in the tree before trying to show a SnackBar.
                  if (!success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(productProvider.errorMessage),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                });
              },
            ),
          ],
        );
      },
    );
  }

  void _showClearAllDialog(BuildContext context) {
    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text(
              'Are you sure you want to remove all tracked products? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  foregroundColor:
                      Theme.of(context).colorScheme.onErrorContainer),
              child: const Text('Delete All'),
              onPressed: () {
                // Pop first, then perform the action
                Navigator.of(dialogContext).pop();
                productProvider.deleteAllProducts();
              },
            ),
          ],
        );
      },
    );
  }

  void _showEngineNotInitializedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Price Engine Not Available'),
          content: const Text(
            'The price engine is not initialized. This might be due to an incorrect chromedriver path. Please check your settings and try again.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Settings'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                ).then((_) {
                  // Retry initialization after returning from settings
                  _initializeEngine();
                });
              },
            ),
            FilledButton(
              child: const Text('Retry'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _initializeEngine();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/images/palertpng1.png',
          height: 32,
          fit: BoxFit.contain,
        ),
        actions: [
          // Engine status indicator
          Consumer<ProductProvider>(
            builder: (context, provider, child) {
              if (_engineInitializationState ==
                  EngineInitializationState.initializing) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                );
              } else if (!provider.hasEngine) {
                return IconButton(
                  icon: const Icon(Icons.warning, color: Colors.orange),
                  tooltip: 'Price engine not initialized',
                  onPressed: () => _showEngineNotInitializedDialog(context),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          // Auto-refresh scheduler
          const AutoRefreshWidget(),
          Consumer<ProductProvider>(
            builder: (context, provider, child) {
              // If products are refreshing, show a stop button and spinner.
              if (provider.isRefreshingAll || provider.isAutoRefreshing) {
                return Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.stop_circle, color: Colors.red),
                      tooltip: 'Stop refreshing',
                      onPressed: () => provider.stopRefreshing(),
                    ),
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    const SizedBox(width: 8),
                  ],
                );
              }
              // If not refreshing and there are products, show the button.
              if (provider.products.isNotEmpty) {
                return IconButton(
                  icon: const Icon(Icons.sync),
                  tooltip: 'Refresh all products',
                  onPressed: provider.refreshAllProducts,
                );
              }
              // Otherwise, show nothing.
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_link),
            tooltip: 'Track new product',
            onPressed: () => _showAddUrlDialog(context),
          ),
          if (productProvider.products.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Remove all products',
              onPressed: () => _showClearAllDialog(context),
            ),
          // Status history button
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'View status history',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const StatusHistoryDialog(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Consumer<ProductProvider>(
          builder: (context, provider, child) {
            // This now shows the loader ONLY if the app is starting up
            if (provider.state == AppState.loading &&
                provider.products.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.products.isEmpty) {
              // Display different content based on engine initialization state
              switch (_engineInitializationState) {
                case EngineInitializationState.initializing:
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Setting up the engine...',
                          style: TextStyle(fontSize: 18),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'This may take a moment.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                case EngineInitializationState.failed:
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.orange, size: 60),
                        const SizedBox(height: 16),
                        const Text(
                          'Price engine failed to initialize.',
                          style: TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Please check the chromedriver path in settings.',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.settings),
                              label: const Text('Settings'),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const SettingsPage()),
                                ).then((_) => _initializeEngine());
                              },
                            ),
                            const SizedBox(width: 16),
                            FilledButton.icon(
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                              onPressed: _initializeEngine,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                case EngineInitializationState.success:
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_shopping_cart,
                            size: 60, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'No products tracked yet.',
                          style: TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Click the "Add Link" icon to track a product.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
              }
            }

            // Using LayoutBuilder for responsive UI
            return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 800) {
                  ProductRecord? currentSelectedProduct;
                  if (provider.selectedProduct != null) {
                    // Use a try-catch to be safe
                    try {
                      currentSelectedProduct = provider.products.firstWhere(
                          (p) => p.id == provider.selectedProduct!.id);
                    } catch (e) {
                      // This happens if the selected product was just deleted.
                      currentSelectedProduct = null;
                    }
                  }

                  return Row(
                    children: [
                      SizedBox(
                        width: 400,
                        child: ProductListView(),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        // Only build the detail view if the product is valid and exists.
                        child: currentSelectedProduct != null
                            ? ProductDetailView(product: currentSelectedProduct)
                            : const Center(
                                child: Text("Select a product to see details")),
                      ),
                    ],
                  );
                } else {
                  // Single-pane layout for smaller screens
                  return ProductListView();
                }
              },
            );
          },
        ),
      ),
    );
  }
}
