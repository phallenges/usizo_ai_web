import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/app_store.dart';
import '../services/integration_stubs.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({required this.store, super.key});

  final AppStore store;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController nameController;
  late final TextEditingController emailController;
  late final TextEditingController allergiesController;
  late final TextEditingController emergencyController;

  @override
  void initState() {
    super.initState();
    final profile = widget.store.profile;
    nameController = TextEditingController(text: profile.name);
    emailController = TextEditingController(text: profile.email);
    allergiesController = TextEditingController(text: profile.allergies);
    emergencyController = TextEditingController(text: profile.emergencyContact);
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    allergiesController.dispose();
    emergencyController.dispose();
    super.dispose();
  }

  void save() {
    widget.store.updateProfile(
      UserProfile(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        allergies: allergiesController.text.trim(),
        emergencyContact: emergencyController.text.trim(),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved on this device.')),
    );
  }

  Future<void> _subscribePremium() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email before subscribing.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show loading
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: SizedBox(
          height: 80,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Processing payment...'),
            ],
          ),
        ),
      ),
    );

    try {
      final gateway = ProductionPaymentGateway();
      final result = await gateway.subscribePremium(
        userEmail: email,
        userName: name.isNotEmpty ? name : 'User',
        context: context,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (result.isSuccess) {
        widget.store.setPremium(true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Welcome to UsizoAI Plus!\nRef: ${result.transactionRef}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Payment failed: ${result.errorReason}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text('Your profile',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          const Text('Your information stays on this device.'),
          const SizedBox(height: 22),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email (optional)',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: allergiesController,
            decoration: const InputDecoration(
              labelText: 'Allergies or sensitivities',
              prefixIcon: Icon(Icons.warning_amber_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: emergencyController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Emergency contact',
              prefixIcon: Icon(Icons.contact_phone_outlined),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save profile'),
          ),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: widget.store,
            builder: (context, _) {
              if (widget.store.isPremium) {
                return Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.green),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'UsizoAI Plus',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text('Unlimited checks enabled.'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: Colors.orange),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Unlock UsizoAI Plus',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 4),
                                Text('Unlimited checks, saved history, and more.'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => _subscribePremium(),
                        child: const Text('Subscribe for \$1.50'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Safety first\n\nUsizoAI does not replace a qualified healthcare professional. Never delay emergency care based on an app suggestion.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'UsizoAI is not a replacement for professional medical care. Always consult a doctor for serious conditions.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
