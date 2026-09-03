import 'package:flutter/material.dart';

import '../l10n/localized.dart';
import '../services/app_store.dart';

/// Screen where the user enters their activation token to unlock UsizoAI Plus.
///
/// The token is generated offline by the admin and sent to the user
/// after they pay via EcoCash.
class ActivateScreen extends StatefulWidget {
  const ActivateScreen({required this.store, super.key});

  final AppStore store;

  @override
  State<ActivateScreen> createState() => _ActivateScreenState();
}

class _ActivateScreenState extends State<ActivateScreen> {
  final controller = TextEditingController();
  bool isActivating = false;
  String? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _onActivate() async {
    final token = controller.text.trim().toUpperCase();

    if (token.isEmpty) {
      setState(() => error = context.tr('activate.enterTokenError'));
      return;
    }

    setState(() {
      isActivating = true;
      error = null;
    });

    final success = await widget.store.activateWithToken(token);

    if (!mounted) return;

    setState(() => isActivating = false);

    if (success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('activate.activatedSuccess')),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.pop(context);
    } else {
      setState(() => error = context.tr('activate.invalidToken'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('activate.title')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(
            context.tr('activate.enterToken'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('activate.tokenInstructions'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: context.tr('activate.tokenHint'),
              labelText: context.tr('activate.activationToken'),
              prefixIcon: const Icon(Icons.vpn_key_outlined),
              errorText: error,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: isActivating ? null : _onActivate,
            icon: isActivating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(isActivating
                ? context.tr('activate.activating')
                : context.tr('activate.activate')),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.tr('activate.howToGetToken'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
