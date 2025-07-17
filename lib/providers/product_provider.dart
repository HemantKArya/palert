import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:palert/providers/status_provider.dart';
import 'package:palert/providers/notification_settings_provider.dart';
import 'package:palert/src/rust/api/models.dart';
import 'package:palert/src/rust/api/price_engine.dart';
import 'package:palert/services/notification_service.dart';

enum AppState { idle, loading, error }

// Auto-refresh time intervals
enum RefreshInterval {
  min5,
  min10,
  min15,
  min20,
  min30,
  min45,
  hour1,
  hour3,
  hour5;

  Duration get duration {
    switch (this) {
      case RefreshInterval.min5:
        return const Duration(minutes: 5);
      case RefreshInterval.min10:
        return const Duration(minutes: 10);
      case RefreshInterval.min15:
        return const Duration(minutes: 15);
      case RefreshInterval.min20:
        return const Duration(minutes: 20);
      case RefreshInterval.min30:
        return const Duration(minutes: 30);
      case RefreshInterval.min45:
        return const Duration(minutes: 45);
      case RefreshInterval.hour1:
        return const Duration(hours: 1);
      case RefreshInterval.hour3:
        return const Duration(hours: 3);
      case RefreshInterval.hour5:
        return const Duration(hours: 5);
    }
  }

  String get label {
    switch (this) {
      case RefreshInterval.min5:
        return '5 minutes';
      case RefreshInterval.min10:
        return '10 minutes';
      case RefreshInterval.min15:
        return '15 minutes';
      case RefreshInterval.min20:
        return '20 minutes';
      case RefreshInterval.min30:
        return '30 minutes';
      case RefreshInterval.min45:
        return '45 minutes';
      case RefreshInterval.hour1:
        return '1 hour';
      case RefreshInterval.hour3:
        return '3 hours';
      case RefreshInterval.hour5:
        return '5 hours';
    }
  }
}

class ProductProvider extends ChangeNotifier {
  PriceEngine? _engine;
  BuildContext? _context;

  // Auto-refresh state
  bool _isAutoRefreshEnabled = false;
  RefreshInterval _refreshInterval = RefreshInterval.min30;
  Timer? _autoRefreshTimer;
  DateTime? _lastRefreshTime;
  DateTime? _nextRefreshTime;
  bool _isAutoRefreshing = false;

  ProductProvider([this._engine]) {
    if (_engine != null) {
      loadProducts();
    }
  }

  // Method to set the engine after initialization
  void setEngine(PriceEngine engine) {
    _engine = engine;
    loadProducts();
    notifyListeners();
  }

  // Check if engine is available
  bool get hasEngine => _engine != null;

  void setContext(BuildContext context) {
    _context = context;
  }

  StatusProvider? get _statusProvider {
    try {
      return _context?.read<StatusProvider>();
    } catch (e) {
      return null;
    }
  }

  List<ProductRecord> _products = [];
  List<ProductRecord> get products => _products;

  AppState _state = AppState.idle;
  AppState get state => _state;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  ProductRecord? _selectedProduct;
  ProductRecord? get selectedProduct => _selectedProduct;

  // New state variables for "Refresh All"
  bool _isRefreshingAll = false;
  bool get isRefreshingAll => _isRefreshingAll;

  double _refreshProgress = 0.0;
  double get refreshProgress => _refreshProgress;

  // Auto-refresh getters
  bool get isAutoRefreshEnabled => _isAutoRefreshEnabled;
  RefreshInterval get refreshInterval => _refreshInterval;
  DateTime? get lastRefreshTime => _lastRefreshTime;
  DateTime? get nextRefreshTime => _nextRefreshTime;
  bool get isAutoRefreshing => _isAutoRefreshing;

  // Get time remaining until next refresh
  Duration? get timeUntilNextRefresh {
    if (_nextRefreshTime == null) return null;
    final now = DateTime.now();
    final remaining = _nextRefreshTime!.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Future<void> loadProducts() async {
    if (_engine == null) {
      _state = AppState.error;
      _errorMessage = "Price engine not initialized";
      _statusProvider?.showError('Price engine not initialized');
      notifyListeners();
      return;
    }

    _state = AppState.loading;
    _statusProvider?.showLoading('Loading products...', id: 'load_products');
    notifyListeners();
    try {
      _products = await _engine!.getAllProductsInDb();
      _products.sort((a, b) => a.title.compareTo(b.title));
      // If there are products, select the first one by default
      if (_products.isNotEmpty && _selectedProduct == null) {
        _selectedProduct = _products.first;
      }
      _state = AppState.idle;
      _statusProvider
          ?.showSuccess('${_products.length} products loaded successfully');
    } catch (e) {
      _state = AppState.error;
      _errorMessage = "Failed to load products: $e";
      _statusProvider?.showError('Failed to load products: $e');
    } finally {
      _statusProvider?.hideStatus(id: 'load_products');
    }
    notifyListeners();
  }

  Future<bool> addProduct(String url) async {
    if (_engine == null) {
      _statusProvider?.showError('Price engine not initialized');
      return false;
    }

    _state = AppState.loading;
    _statusProvider?.showLoading('Adding product from URL...',
        id: 'add_product');
    notifyListeners();
    try {
      final newProduct = await _engine!.fetchAndUpdateProduct(url: url);
      // Check if product already exists and update it
      final index = _products.indexWhere((p) => p.id == newProduct.id);
      if (index != -1) {
        _products[index] = newProduct;
        _statusProvider?.showSuccess('Product updated successfully');
      } else {
        _products.add(newProduct);
        _statusProvider?.showSuccess('Product added successfully');
      }
      _products.sort((a, b) => a.title.compareTo(b.title));
      _selectedProduct = newProduct;
      _state = AppState.idle;
      notifyListeners();
      return true;
    } catch (e) {
      _state = AppState.error;
      _errorMessage = "Failed to add product: $e";
      _statusProvider?.showError('Failed to add product: $e');
      notifyListeners();
      return false;
    } finally {
      _statusProvider?.hideStatus(id: 'add_product');
    }
  }

  Future<void> refreshProduct(ProductRecord product) async {
    if (_engine == null) {
      _statusProvider?.showError('Price engine not initialized');
      return;
    }

    // Don't allow refreshing a product if a global refresh is in progress
    if (_isRefreshingAll || _isAutoRefreshing) {
      _statusProvider?.showWarning(
          'A global refresh operation is already in progress. Please wait for it to complete.');
      return;
    }

    _state = AppState.loading;
    _statusProvider?.showLoading('Refreshing ${product.title}...',
        id: 'refresh_product_${product.id}');
    notifyListeners();
    try {
      final updatedProduct =
          await _engine!.fetchAndUpdateProduct(url: product.url);

      // Check for changes and send notifications based on settings
      await _checkAndSendNotifications(product, updatedProduct);

      final index = _products.indexWhere((p) => p.id == updatedProduct.id);
      if (index != -1) {
        _products[index] = updatedProduct;
        if (_selectedProduct?.id == updatedProduct.id) {
          _selectedProduct = updatedProduct;
        }
      }
      _state = AppState.idle;
      _statusProvider?.showSuccess('Product refreshed successfully');

      // Reset auto-refresh timer after manual refresh
      if (_isAutoRefreshEnabled) {
        _lastRefreshTime = DateTime.now();
        _scheduleNextRefresh();
      }
    } catch (e) {
      _state = AppState.error;
      _errorMessage = "Failed to refresh product: $e";
      _statusProvider?.showError('Failed to refresh product: $e');
    } finally {
      _statusProvider?.hideStatus(id: 'refresh_product_${product.id}');
    }
    notifyListeners();
  }

  Future<void> refreshAllProducts() async {
    await _refreshAllProductsInternal();

    // Reset auto-refresh timer after manual refresh
    if (_isAutoRefreshEnabled) {
      _lastRefreshTime = DateTime.now();
      _scheduleNextRefresh();
    }
  }

  Future<void> _refreshAllProductsInternal() async {
    if (_isRefreshingAll) return; // Prevent multiple concurrent refreshes
    if (_engine == null) {
      _statusProvider?.showError('Price engine not initialized');
      return;
    }

    // Check if any product is currently being refreshed by checking state
    if (_state == AppState.loading) {
      _statusProvider?.showWarning(
          'A product refresh operation is in progress. Please wait for it to complete.');
      return;
    }

    _isRefreshingAll = true;
    _refreshProgress = 0.0;
    // Reload products from DB to ensure we have the latest list
    await loadProducts();

    _statusProvider?.showLoading(
        'Refreshing all products... (0/${_products.length})',
        id: 'refresh_all');
    notifyListeners();

    try {
      // Create a working copy of product IDs to track progress
      final productIds = _products.map((p) => p.id).toList();
      int processedCount = 0;
      final totalCount = productIds.length;

      if (totalCount == 0) return;

      for (final productId in productIds) {
        // Check if refresh was stopped
        if (!_isRefreshingAll) {
          _statusProvider?.showInfo('Refresh operation was stopped by user');
          break;
        }

        // Find the current product in the list (it might have moved or been deleted)
        final currentIndex = _products.indexWhere((p) => p.id == productId);

        // Skip if product was deleted during refresh
        if (currentIndex == -1) {
          processedCount++;
          _refreshProgress = processedCount / totalCount;
          _statusProvider?.updateStatus(
            id: 'refresh_all',
            message:
                'Skipping deleted product... ($processedCount/$totalCount)',
          );
          notifyListeners();
          continue;
        }

        final product = _products[currentIndex];

        try {
          // Update status with current progress
          _statusProvider?.updateStatus(
            id: 'refresh_all',
            message:
                'Refreshing all products... (${processedCount + 1}/$totalCount)',
          );

          // Fetch the updated product
          final updatedProduct =
              await _engine!.fetchAndUpdateProduct(url: product.url);

          // Check for changes and send notifications based on settings
          await _checkAndSendNotifications(product, updatedProduct);

          // Find the product again in case the list was modified during the update
          final updatedIndex = _products.indexWhere((p) => p.id == productId);
          if (updatedIndex != -1) {
            // Replace it in the list
            _products[updatedIndex] = updatedProduct;
            // If it was the selected product, update that too
            if (_selectedProduct?.id == updatedProduct.id) {
              _selectedProduct = updatedProduct;
            }
          }
        } catch (e) {
          debugPrint("Failed to refresh product ${product.id}: $e");
          _statusProvider?.showWarning('Failed to refresh ${product.title}');
          // Continue with the next product
        }

        processedCount++;
        _refreshProgress = processedCount / totalCount;
        notifyListeners();
        // A small delay to make the progress bar animation smoother
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (_isRefreshingAll) {
        // Only show success if not stopped by user
        _statusProvider?.showSuccess('All products refreshed successfully');
      }
    } catch (e) {
      _statusProvider?.showError('Failed to refresh all products: $e');
    } finally {
      _isRefreshingAll = false;
      _statusProvider?.hideStatus(id: 'refresh_all');
      notifyListeners();
    }
  }

  Future<ProductRecord?> deleteProduct(String productId) async {
    if (_engine == null) {
      _statusProvider?.showError('Price engine not initialized');
      return _selectedProduct;
    }

    // Check if global refresh is in progress
    if (_isRefreshingAll || _isAutoRefreshing) {
      _statusProvider?.showWarning(
        'Cannot delete product while refresh operation is in progress. Please wait for it to complete.',
      );
      return _selectedProduct;
    }

    print('deleteProduct called with ID: $productId');
    final index = _products.indexWhere((p) => p.id == productId);
    if (index == -1) {
      print('Product not found in list: $productId');
      _statusProvider?.showWarning('Product not found');
      return _selectedProduct;
    }

    final productTitle = _products[index].title;
    print(
        'Product found at index: $index, attempting to delete from database...');
    _statusProvider?.showLoading('Deleting $productTitle...',
        id: 'delete_product_$productId');

    try {
      await _engine!.removeProductById(productId: productId);
      print('Successfully removed from database, updating local state...');
      _products.removeAt(index);

      if (_selectedProduct?.id == productId) {
        if (_products.isEmpty) {
          _selectedProduct = null;
        } else {
          final newIndex = (index > 0) ? index - 1 : 0;
          _selectedProduct = _products[newIndex];
        }
      }

      _statusProvider?.showSuccess('Product deleted successfully');
      notifyListeners();
      print('Product deletion completed successfully');
      return _selectedProduct;
    } catch (e) {
      print('Error deleting product: $e');
      _state = AppState.error;
      _errorMessage = "Failed to delete product: $e";
      _statusProvider?.showError('Failed to delete product: $e');
      notifyListeners();
      return _selectedProduct;
    } finally {
      _statusProvider?.hideStatus(id: 'delete_product_$productId');
    }
  }

  Future<void> deleteAllProducts() async {
    if (_engine == null) {
      _statusProvider?.showError('Price engine not initialized');
      return;
    }

    // Check if global refresh is in progress
    if (_isRefreshingAll || _isAutoRefreshing) {
      _statusProvider?.showWarning(
        'Cannot delete products while refresh operation is in progress. Please wait for it to complete.',
      );
      return;
    }

    _state = AppState.loading;
    _statusProvider?.showLoading('Deleting all products...', id: 'delete_all');
    notifyListeners();
    try {
      // Create a copy of the list to avoid modification during iteration issues
      final productIds = _products.map((p) => p.id).toList();
      for (final productId in productIds) {
        await _engine!.removeProductById(productId: productId);
      }
      _products.clear();
      _selectedProduct = null;
      _state = AppState.idle;
      _statusProvider?.showSuccess('All products deleted successfully');
    } catch (e) {
      _state = AppState.error;
      _errorMessage = "Failed to delete all products: $e";
      _statusProvider?.showError('Failed to delete all products: $e');
    } finally {
      _statusProvider?.hideStatus(id: 'delete_all');
    }
    notifyListeners();
  }

  void selectProduct(ProductRecord? product) {
    _selectedProduct = product;
    notifyListeners();
  }

  // Add stop refresh method
  void stopRefreshing() {
    if (_isRefreshingAll) {
      _isRefreshingAll = false;
      _statusProvider?.showInfo('Refresh operation stopped');
      _state = AppState.idle;
      notifyListeners();
    }

    if (_isAutoRefreshing) {
      _isAutoRefreshing = false;
      _statusProvider?.showInfo('Auto-refresh operation stopped');
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  // Auto-refresh methods
  void enableAutoRefresh(RefreshInterval interval) {
    _isAutoRefreshEnabled = true;
    _refreshInterval = interval;
    _scheduleNextRefresh();
    _statusProvider?.showSuccess('Auto-refresh enabled: ${interval.label}');
    notifyListeners();
  }

  void disableAutoRefresh() {
    _isAutoRefreshEnabled = false;
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
    _nextRefreshTime = null;
    _statusProvider?.showInfo('Auto-refresh disabled');
    notifyListeners();
  }

  void updateRefreshInterval(RefreshInterval interval) {
    _refreshInterval = interval;
    if (_isAutoRefreshEnabled) {
      _scheduleNextRefresh();
      _statusProvider
          ?.showInfo('Auto-refresh interval updated: ${interval.label}');
    }
    notifyListeners();
  }

  void _scheduleNextRefresh() {
    _autoRefreshTimer?.cancel();
    _nextRefreshTime = DateTime.now().add(_refreshInterval.duration);

    _autoRefreshTimer = Timer(_refreshInterval.duration, () {
      if (_isAutoRefreshEnabled && !_isAutoRefreshing) {
        _performAutoRefresh();
      }
    });
  }

  Future<void> _performAutoRefresh() async {
    if (_isAutoRefreshing || !_isAutoRefreshEnabled || _isRefreshingAll) return;

    _isAutoRefreshing = true;
    _statusProvider?.showLoading('Time reached - auto-refresh starting...',
        id: 'auto_refresh');
    notifyListeners();

    try {
      await _refreshAllProductsInternal();
      _lastRefreshTime = DateTime.now();
      _statusProvider?.updateStatus(
        id: 'auto_refresh',
        message: 'Auto-refresh completed successfully',
        type: StatusType.success,
      );

      // Schedule the next refresh
      if (_isAutoRefreshEnabled) {
        _scheduleNextRefresh();
      }
    } catch (e) {
      _statusProvider?.showError('Auto-refresh failed: $e');
      // Still schedule next refresh even if this one failed
      if (_isAutoRefreshEnabled) {
        _scheduleNextRefresh();
      }
    } finally {
      _isAutoRefreshing = false;
      _statusProvider?.hideStatus(id: 'auto_refresh');
      notifyListeners();
    }
  }

  /// Creates a backup of all products and their price history
  Future<void> createBackup(String backupPath) async {
    if (_engine == null) {
      _statusProvider?.showError('Price engine not initialized');
      return;
    }

    try {
      _statusProvider?.showLoading('Creating backup...');

      await _engine!.createBackup(backupPath: backupPath);

      _statusProvider?.showSuccess('Backup created successfully');
    } catch (e) {
      _statusProvider?.showError('Failed to create backup: $e');
      rethrow;
    } finally {
      _statusProvider?.hideStatus();
    }
  }

  /// Restores products and price history from a backup file
  Future<void> restoreFromBackup(
      String backupPath, bool replaceExisting) async {
    if (_engine == null) {
      _statusProvider?.showError('Price engine not initialized');
      return;
    }

    try {
      _statusProvider?.showLoading('Restoring from backup...');

      await _engine!.restoreFromBackup(
          backupPath: backupPath, replaceExisting: replaceExisting);

      _statusProvider?.showSuccess('Backup restored successfully');
    } catch (e) {
      _statusProvider?.showError('Failed to restore backup: $e');
      rethrow;
    } finally {
      _statusProvider?.hideStatus();
    }
  }

  /// Checks for changes between old and new product data and sends appropriate notifications
  Future<void> _checkAndSendNotifications(
      ProductRecord oldProduct, ProductRecord newProduct) async {
    if (_context == null) return;

    final notificationSettings =
        Provider.of<NotificationSettingsProvider>(_context!, listen: false);

    // Get old and new data
    final oldPrice = oldProduct.priceHistory.isNotEmpty
        ? oldProduct.priceHistory.last.price
        : 0;
    final newPrice = newProduct.priceHistory.isNotEmpty
        ? newProduct.priceHistory.last.price
        : 0;
    final oldInStock = oldProduct.priceHistory.isNotEmpty
        ? oldProduct.priceHistory.last.inStock
        : false;
    final newInStock = newProduct.priceHistory.isNotEmpty
        ? newProduct.priceHistory.last.inStock
        : false;

    final imageUrl =
        newProduct.images.isNotEmpty ? newProduct.images.first : null;

    // Check for price drop
    if (newPrice < oldPrice && notificationSettings.priceDropEnabled) {
      await NotificationService.showPriceDropNotification(
        title: newProduct.title,
        imageUrl: imageUrl,
        oldPrice: oldPrice,
        newPrice: newPrice,
      );
    }

    // Check for price increase
    if (newPrice > oldPrice && notificationSettings.priceIncreaseEnabled) {
      await NotificationService.showPriceIncreaseNotification(
        title: newProduct.title,
        imageUrl: imageUrl,
        oldPrice: oldPrice,
        newPrice: newPrice,
      );
    }

    // Check for back in stock
    if (!oldInStock && newInStock && notificationSettings.backInStockEnabled) {
      await NotificationService.showBackInStockNotification(
        title: newProduct.title,
        imageUrl: imageUrl,
      );
    }

    // Check for out of stock
    if (oldInStock && !newInStock && notificationSettings.outOfStockEnabled) {
      await NotificationService.showOutOfStockNotification(
        title: newProduct.title,
        imageUrl: imageUrl,
      );
    }
  }
}
