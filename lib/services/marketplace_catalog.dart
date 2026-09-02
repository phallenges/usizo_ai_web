import '../models/product.dart';
import '../models/vendor.dart';
import 'product_catalog.dart';
import 'vendor_catalog.dart';
import 'vendor_store.dart';

/// Merges bundled marketplace data with vendor-posted listings.
class MarketplaceCatalog {
  const MarketplaceCatalog({
    required this.products,
    required this.vendors,
  });

  final List<Product> products;
  final List<Vendor> vendors;

  static Future<MarketplaceCatalog> load(VendorStore vendorStore) async {
    final bundledProducts = await ProductCatalog.load();
    final bundledVendors = await VendorCatalog.load();

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
