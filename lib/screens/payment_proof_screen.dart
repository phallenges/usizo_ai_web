import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/order.dart';
import '../models/vendor.dart';
import '../services/app_store.dart';

/// Lets a buyer submit a screenshot or photo after paying a vendor by EcoCash.
class PaymentProofScreen extends StatefulWidget {
  const PaymentProofScreen({
    required this.store,
    required this.order,
    required this.vendor,
    super.key,
  });

  final AppStore store;
  final Order order;
  final Vendor vendor;

  @override
  State<PaymentProofScreen> createState() => _PaymentProofScreenState();
}

class _PaymentProofScreenState extends State<PaymentProofScreen> {
  final _picker = ImagePicker();
  Uint8List? _proofBytes;
  bool _submitting = false;

  Future<void> _pick(ImageSource source) async {
    final image = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 70,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() => _proofBytes = bytes);
  }

  Future<void> _chooseProof() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose confirmation image'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pick(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pick(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final bytes = _proofBytes;
    if (bytes == null || _submitting) return;
    setState(() => _submitting = true);
    widget.store.submitPaymentProof(widget.order.id, base64Encode(bytes));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Payment proof submitted for verification.')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paymentNumber = widget.vendor.ecocashNumber.isNotEmpty
        ? widget.vendor.ecocashNumber
        : widget.vendor.phone;
    return Scaffold(
      appBar: AppBar(title: const Text('Pay with EcoCash')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(widget.order.totalLabel,
                      style: theme.textTheme.headlineLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      )),
                  const SizedBox(height: 4),
                  Text('Send this amount to ${widget.vendor.name}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('1. Send your EcoCash payment',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.phone_android_outlined),
              title: Text(
                  paymentNumber.isEmpty
                      ? 'Vendor number unavailable'
                      : paymentNumber,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Text('EcoCash account: ${widget.vendor.name}'),
              trailing: paymentNumber.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.copy_outlined),
                      tooltip: 'Copy number',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: paymentNumber));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('EcoCash number copied')),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('2. Upload your transfer confirmation',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
              'The vendor will check the payment in EcoCash before processing your order.',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _chooseProof,
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(_proofBytes == null
                ? 'Upload confirmation image'
                : 'Change image'),
          ),
          if (_proofBytes != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(_proofBytes!,
                  height: 220, width: double.infinity, fit: BoxFit.cover),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _proofBytes == null || _submitting ? null : _submit,
            icon: const Icon(Icons.verified_outlined),
            label:
                Text(_submitting ? 'Submitting...' : 'Submit for verification'),
          ),
          const SizedBox(height: 10),
          Text(
              'A confirmation image is not automatic approval. The vendor must verify the payment.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
