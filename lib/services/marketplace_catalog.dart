import '../models/product.dart';
import '../models/vendor.dart';
import 'backend_api.dart';

/// Loads the live marketplace catalog from the backend.
class MarketplaceCatalog {
  const MarketplaceCatalog({
    required this.products,
    required this.vendors,
  });

  final List<Product> products;
  final List<Vendor> vendors;

  static Future<MarketplaceCatalog> load(
    BackendApi? backendApi,
  ) async {
    if (backendApi == null || !backendApi.isConfigured) {
      return const MarketplaceCatalog(products: [], vendors: []);
    }
    return MarketplaceCatalog(
      products: await backendApi.fetchProducts(),
      vendors: await backendApi.fetchVendors(),
    );
  }
}
