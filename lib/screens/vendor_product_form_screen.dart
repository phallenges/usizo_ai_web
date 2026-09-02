import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/product.dart';
import '../services/vendor_store.dart';

/// Form for vendors to add or edit a marketplace product.
class VendorProductFormScreen extends StatefulWidget {
  const VendorProductFormScreen({
    required this.vendorStore,
    this.product,
    super.key,
  });

  final VendorStore vendorStore;
  final Product? product;

  @override
  State<VendorProductFormScreen> createState() =>
      _VendorProductFormScreenState();
}

class _VendorProductFormScreenState extends State<VendorProductFormScreen> {
  static const categories = [
    'Herbal remedy',
    'Herbal tea',
    'Capsules',
    'Herbal blend',
    'Topical',
    'Tincture',
    'Herbal powder',
    'Superfood',
  ];

  late final TextEditingController nameController;
  late final TextEditingController descriptionController;
  late final TextEditingController priceController;
  late final TextEditingController tagsController;

  late String category;
  late bool inStock;
  late bool canBuyOnline;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    nameController = TextEditingController(text: product?.name ?? '');
    descriptionController =
        TextEditingController(text: product?.description ?? '');
    priceController = TextEditingController(
      text: product != null
          ? (product.priceCents / 100).toStringAsFixed(2)
          : '',
    );
    tagsController =
        TextEditingController(text: product?.tags.join(', ') ?? '');
    category = product?.category ?? categories.first;
    inStock = product?.inStock ?? true;
    canBuyOnline = product?.canBuyOnline ?? false;
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    tagsController.dispose();
    super.dispose();
  }

  int? _parsePriceCents() {
    final value = double.tryParse(priceController.text.trim());
    if (value == null || value <= 0) return null;
    return (value * 100).round();
  }

  List<String> _parseTags() {
    return tagsController.text
        .split(',')
        .map((tag) => tag.trim().toLowerCase())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }

  void _save() {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      _showError('Enter a product name.');
      return;
    }

    final priceCents = _parsePriceCents();
    if (priceCents == null) {
      _showError('Enter a valid price.');
      return;
    }

    final tags = _parseTags();
    final description = descriptionController.text.trim();

    if (widget.product == null) {
      widget.vendorStore.addProduct(
        name: name,
        description: description,
        category: category,
        priceCents: priceCents,
        tags: tags,
        inStock: inStock,
        canBuyOnline: canBuyOnline,
      );
    } else {
      widget.vendorStore.updateProduct(
        widget.product!.copyWith(
          name: name,
          description: description,
          category: category,
          priceCents: priceCents,
          tags: tags,
          inStock: inStock,
          canBuyOnline: canBuyOnline,
        ),
      );
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.product == null
              ? 'Product listed in marketplace'
              : 'Product updated',
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit product' : 'Add product'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Product name',
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descriptionController,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Description',
              prefixIcon: Icon(Icons.notes_outlined),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: category,
            decoration: const InputDecoration(
              labelText: 'Category',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: categories
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(item),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => category = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: const InputDecoration(
              labelText: 'Price (USD)',
              prefixIcon: Icon(Icons.attach_money),
              prefixText: '\$ ',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: tagsController,
            decoration: const InputDecoration(
              labelText: 'Tags (comma separated)',
              prefixIcon: Icon(Icons.sell_outlined),
              helperText: 'e.g. moringa, immunity, tea',
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('In stock'),
            subtitle: const Text('Show as available to customers'),
            value: inStock,
            onChanged: (value) => setState(() => inStock = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Available for online purchase'),
            subtitle: const Text('Shows "Buy now" when customer is online'),
            value: canBuyOnline,
            onChanged: (value) => setState(() => canBuyOnline = value),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _save,
            icon: Icon(isEditing ? Icons.save_outlined : Icons.publish_outlined),
            label: Text(isEditing ? 'Save changes' : 'Publish product'),
          ),
        ],
      ),
    );
  }
}
