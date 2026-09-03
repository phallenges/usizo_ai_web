import '../models/product.dart';
import '../models/vendor.dart';
import 'backend_api.dart';
import 'product_catalog.dart';
import 'vendor_catalog.dart';
import 'vendor_store.dart';

/// Merges API data, bundled assets, and vendor-posted listings.
///
/// When the backend API is reachable the catalog is loaded from the server;
/// otherwise the app falls back to bundled JSON assets so it works offline.
class MarketplaceCatalog {
  const MarketplaceCatalog({
    required this.products,
    required this.vendors,
  });

  final List<Product> products;
  final List<Vendor> vendors;

  static Future<MarketplaceCatalog> load(
    VendorStore vendorStore,
    BackendApi? backendApi,
  ) async {
    // Try the API first when configured.
    List<Vendor> apiVendors = [];
    List<Product> apiProducts = [];
    if (backendApi != null && backendApi.isConfigured) {
      apiVendors = await backendApi.fetchVendors();
      apiProducts = await backendApi.fetchProducts();
    }

    // Fall back to bundled assets when the API returns nothing.
    final bundledVendors = apiVendors.isNotEmpty
        ? apiVendors
        : await VendorCatalog.load();
    final bundledProducts = apiProducts.isNotEmpty
        ? apiProducts
        : await ProductCatalog.load();

    // Merge in vendor-posted listings from the local vendor store.
    final vendors = <Vendor>[...bundledVendors];
    for (final vendor in vendorStore.registeredVendors) {
      if (!vendors.any((v) => v.id == vendor.id)) {
        vendors.add(vendor);
      }
    }

    final products = <Product>[...bundledProducts];
    for (final product in vendorStore.vendorProducts) {
      final index = products.indexWhere((p) => p.id == product.id);
      if (index >= 0) {
        products[index] = product;
      } else {
        products.add(product);
      }
    }

    return MarketplaceCatalog(products: products, vendors: vendors);
  }
}
