import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/localized.dart';
import '../services/vendor_store.dart';
import '../services/app_store.dart';
import 'vendor_dashboard_screen.dart';

/// Vendor sign-up and sign-in.
class VendorAuthScreen extends StatefulWidget {
  const VendorAuthScreen(
      {required this.vendorStore, required this.store, super.key});

  final VendorStore vendorStore;
  final AppStore store;

  @override
  State<VendorAuthScreen> createState() => _VendorAuthScreenState();
}

class _VendorAuthScreenState extends State<VendorAuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final signInPhoneController = TextEditingController();
  final signInPinController = TextEditingController();

  final signUpNameController = TextEditingController();
  final signUpLocationController = TextEditingController();
  final signUpPhoneController = TextEditingController();
  final signUpEcocashController = TextEditingController();
  final signUpWhatsappController = TextEditingController();
  final signUpDescriptionController = TextEditingController();
  final signUpPinController = TextEditingController();
  final signUpConfirmPinController = TextEditingController();

  String? error;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    signInPhoneController.dispose();
    signInPinController.dispose();
    signUpNameController.dispose();
    signUpLocationController.dispose();
    signUpPhoneController.dispose();
    signUpEcocashController.dispose();
    signUpWhatsappController.dispose();
    signUpDescriptionController.dispose();
    signUpPinController.dispose();
    signUpConfirmPinController.dispose();
    super.dispose();
  }

  void _openDashboard() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VendorDashboardScreen(
            vendorStore: widget.vendorStore, store: widget.store),
      ),
    );
  }

  Future<void> _signIn() async {
    setState(() {
      error = null;
      isSubmitting = true;
    });

    final result = await widget.vendorStore.signIn(
      phone: signInPhoneController.text,
      pin: signInPinController.text,
    );

    if (!mounted) return;
    setState(() => isSubmitting = false);

    if (result == null) {
      _openDashboard();
    } else {
      setState(() => error = result);
    }
  }

  Future<void> _signUp() async {
    if (signUpPinController.text != signUpConfirmPinController.text) {
      setState(() => error = 'PINs do not match.');
      return;
    }

    setState(() {
      error = null;
      isSubmitting = true;
    });

    final result = await widget.vendorStore.signUp(
      businessName: signUpNameController.text,
      location: signUpLocationController.text,
      phone: signUpPhoneController.text,
      ecocashNumber: signUpEcocashController.text,
      whatsapp: signUpWhatsappController.text,
      description: signUpDescriptionController.text,
      pin: signUpPinController.text,
    );

    if (!mounted) return;
    setState(() => isSubmitting = false);

    if (result == null) {
      _openDashboard();
    } else {
      setState(() => error = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('vendorAuth.title')),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: context.tr('vendorAuth.signIn')),
            Tab(text: context.tr('vendorAuth.signUp')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SignInForm(
            phoneController: signInPhoneController,
            pinController: signInPinController,
            error: error,
            isSubmitting: isSubmitting,
            onSubmit: _signIn,
          ),
          _SignUpForm(
            nameController: signUpNameController,
            locationController: signUpLocationController,
            phoneController: signUpPhoneController,
            ecocashController: signUpEcocashController,
            whatsappController: signUpWhatsappController,
            descriptionController: signUpDescriptionController,
            pinController: signUpPinController,
            confirmPinController: signUpConfirmPinController,
            error: error,
            isSubmitting: isSubmitting,
            onSubmit: _signUp,
          ),
        ],
      ),
    );
  }
}

class _SignInForm extends StatelessWidget {
  const _SignInForm({
    required this.phoneController,
    required this.pinController,
    required this.error,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final TextEditingController phoneController;
  final TextEditingController pinController;
  final String? error;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(
          context.tr('vendorAuth.signInTitle'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          context.tr('vendorAuth.signInSubtitle'),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: context.tr('vendorAuth.phoneNumber'),
            prefixIcon: const Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: pinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: context.tr('vendorAuth.pin'),
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: isSubmitting ? null : onSubmit,
          child: Text(isSubmitting
              ? context.tr('vendorAuth.signingIn')
              : context.tr('vendorAuth.signIn')),
        ),
      ],
    );
  }
}

class _SignUpForm extends StatelessWidget {
  const _SignUpForm({
    required this.nameController,
    required this.locationController,
    required this.phoneController,
    required this.ecocashController,
    required this.whatsappController,
    required this.descriptionController,
    required this.pinController,
    required this.confirmPinController,
    required this.error,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final TextEditingController nameController;
  final TextEditingController locationController;
  final TextEditingController phoneController;
  final TextEditingController ecocashController;
  final TextEditingController whatsappController;
  final TextEditingController descriptionController;
  final TextEditingController pinController;
  final TextEditingController confirmPinController;
  final String? error;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(
          context.tr('vendorAuth.signUpTitle'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          context.tr('vendorAuth.signUpSubtitle'),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: nameController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: context.tr('vendorAuth.businessName'),
            prefixIcon: const Icon(Icons.store_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: locationController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: context.tr('vendorAuth.location'),
            prefixIcon: const Icon(Icons.location_on_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: context.tr('vendorAuth.phoneNumber'),
            prefixIcon: const Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: ecocashController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'EcoCash number',
            prefixIcon: Icon(Icons.account_balance_wallet_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: whatsappController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: context.tr('vendorAuth.whatsappOptional'),
            prefixIcon: const Icon(Icons.chat_outlined),
            helperText: context.tr('vendorAuth.whatsappDefault'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: descriptionController,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: context.tr('vendorAuth.aboutBusiness'),
            prefixIcon: const Icon(Icons.info_outline),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: pinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: context.tr('vendorAuth.createPin'),
            prefixIcon: const Icon(Icons.lock_outline),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: confirmPinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: context.tr('vendorAuth.confirmPin'),
            prefixIcon: const Icon(Icons.lock_outline),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: isSubmitting ? null : onSubmit,
          child: Text(isSubmitting
              ? context.tr('vendorAuth.creatingAccount')
              : context.tr('vendorAuth.createVendorAccount')),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              context.tr('vendorAuth.shopSavedNote'),
            ),
          ),
        ),
      ],
    );
  }
}
