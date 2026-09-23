import 'package:flutter/material.dart';

import '../l10n/localized.dart';
import '../models/user_profile.dart';
import '../services/app_store.dart';
import '../services/app_updater.dart';
import '../services/payment_service.dart';
import '../widgets/update_check_tile.dart';
import 'activate_screen.dart';
import 'payment_details_screen.dart';
import 'remedy_submission_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.store,
    this.updater,
    this.openUpgrade = false,
    this.onUpgradeOpened,
    super.key,
  });

  final AppStore store;
  final AppUpdater? updater;
  final bool openUpgrade;
  final VoidCallback? onUpgradeOpened;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController allergiesController;
  late final TextEditingController conditionsController;
  late final TextEditingController medicationsController;
  late final TextEditingController emergencyController;
  var _medicalInfoExpanded = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.store.profile;
    allergiesController = TextEditingController(text: profile.allergies);
    conditionsController =
        TextEditingController(text: profile.medicalConditions);
    medicationsController =
        TextEditingController(text: profile.currentMedications);
    emergencyController = TextEditingController(text: profile.emergencyContact);
    if (widget.openUpgrade) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _subscribePremium();
      });
    }
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.openUpgrade && !oldWidget.openUpgrade) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _subscribePremium();
      });
    }
  }

  @override
  void dispose() {
    allergiesController.dispose();
    conditionsController.dispose();
    medicationsController.dispose();
    emergencyController.dispose();
    super.dispose();
  }

  void save() {
    widget.store.updateProfile(
      UserProfile(
        name: widget.store.profile.name,
        email: widget.store.profile.email,
        allergies: allergiesController.text.trim(),
        medicalConditions: conditionsController.text.trim(),
        currentMedications: medicationsController.text.trim(),
        emergencyContact: emergencyController.text.trim(),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('profile.saved'))),
    );
  }

  Future<void> _subscribePremium() async {
    widget.onUpgradeOpened?.call();
    final name = widget.store.profile.name;

    final instruction = PaymentService().subscriptionInstruction(
      userName: name.isNotEmpty ? name : 'User',
    );

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentDetailsScreen(
          instruction: instruction,
          store: widget.store,
        ),
      ),
    );
  }

  void _activateToken() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivateScreen(store: widget.store),
      ),
    );
  }

  void _openRemedySubmission() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RemedySubmissionScreen(api: widget.store.backendApi),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(
            'Your profile',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xff153f36),
                ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Manage your care preferences, Plus access, and community contributions.',
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: () => setState(
              () => _medicalInfoExpanded = !_medicalInfoExpanded,
            ),
            icon: Icon(
              _medicalInfoExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.medical_information_outlined,
            ),
            label: Text(
              _medicalInfoExpanded
                  ? 'Hide medical information'
                  : 'Medical information',
            ),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              foregroundColor: const Color(0xff153f36),
              side: const BorderSide(color: Color(0x24153f36)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _medicalInfoExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(height: 8),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                children: [
                  TextField(
                    controller: allergiesController,
                    decoration: const InputDecoration(
                      labelText: 'Allergies',
                      prefixIcon: Icon(Icons.warning_amber_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: conditionsController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Medical conditions',
                      hintText: 'For example: asthma, diabetes, hypertension',
                      prefixIcon: Icon(Icons.medical_information_outlined),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: medicationsController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Current medications',
                      hintText: 'List medicines or supplements you currently use',
                      prefixIcon: Icon(Icons.medication_outlined),
                      alignLabelWithHint: true,
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
                    label: const Text('Save medical information'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.volunteer_activism_outlined),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Contribute to the remedy library',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Share a carefully researched remedy or food-based wellness suggestion. Submissions are reviewed before they are published.',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _openRemedySubmission,
                    child: const Text('Suggest a remedy'),
                  ),
                ],
              ),
            ),
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
                            children: [
                              Text(
                                context.tr('profile.usizoPlus'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                  context.tr('profile.unlimitedChecksEnabled')),
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
                              children: [
                                Text(
                                  context.tr('profile.unlockPlus'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(context.tr('profile.plusDescription')),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _subscribePremium,
                        child: Text(context.tr('profile.payWithEcoCash')),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _activateToken,
                        child: Text(context.tr('profile.hasToken')),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: widget.store,
            builder: (context, _) {
              final orders = widget.store.orders;
              if (orders.isEmpty) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('profile.orderHistory'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ...orders.take(5).map(
                        (order) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.receipt_long_outlined),
                            title: Text(order.reference),
                            subtitle: Text(
                              '${order.items.length} item(s) · ${order.status.name}',
                            ),
                            trailing: Text(
                              order.totalLabel,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                  const SizedBox(height: 4),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          UpdateCheckTile(updater: widget.updater),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.tr('market.safetyFirst'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('market.disclaimer'),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
