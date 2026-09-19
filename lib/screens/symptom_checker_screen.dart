import 'package:flutter/material.dart';

import '../l10n/localized.dart';
import '../models/remedy.dart';
import '../services/app_store.dart';
import '../services/symptom_checker.dart';
import '../widgets/premium_banner.dart';
import '../widgets/remedy_card.dart';
import '../widgets/usizo_logo.dart';
import 'emergency_screen.dart';

class SymptomCheckerScreen extends StatefulWidget {
  const SymptomCheckerScreen({
    required this.store,
    required this.remedies,
    required this.checker,
    this.onUpgrade,
    super.key,
  });

  final AppStore store;
  final List<Remedy> remedies;
  final SymptomChecker checker;
  final VoidCallback? onUpgrade;

  @override
  State<SymptomCheckerScreen> createState() => _SymptomCheckerScreenState();
}

class _SymptomCheckerScreenState extends State<SymptomCheckerScreen> {
  final controller = TextEditingController();
  CheckResult? result;
  bool isChecking = false;

  String get _timeGreeting {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Good night';
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    if (hour < 22) return 'Good evening';
    return 'Good night';
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _showUpgradeDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Free checks used'),
        content: const Text(
          'You have used your three free checks. Upgrade to Plus for unlimited offline checks.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onUpgrade?.call();
            },
            child: const Text('Upgrade to Plus'),
          ),
        ],
      ),
    );
  }

  void checkSymptoms() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Describe at least one symptom.')),
      );
      return;
    }

    if (!widget.store.canCheck) {
      await _showUpgradeDialog();
      return;
    }

    setState(() => isChecking = true);
    try {
      final checked =
          await widget.checker.analyze(controller.text, widget.remedies);
      if (checked.isEmergency) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EmergencyScreen(reason: checked.emergencyReason!),
          ),
        );
        return;
      }

      widget.store.recordCheck();
      if (mounted) {
        setState(() => result = checked);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const UsizoLogo(size: 44, showText: false),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_timeGreeting, style: theme.textTheme.labelLarge),
                    Text(
                      widget.store.profile.name.isEmpty
                          ? 'Your health, in context.'
                          : widget.store.profile.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xff153f36),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_none_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xff153f36),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'A clearer next step starts here.',
            style: theme.textTheme.headlineMedium?.copyWith(
              height: .98,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              color: const Color(0xff153f36),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('checker.subtitle'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xff66736d),
            ),
          ),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: widget.store,
            builder: (context, _) => PremiumBanner(
              isPremium: widget.store.isPremium,
              onPressed: () {
                if (widget.store.isPremium) {
                  widget.onUpgrade?.call();
                } else {
                  _showUpgradeDialog();
                }
              },
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.tr('checker.howAreYou'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xff153f36),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            minLines: 4,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            enabled: !isChecking,
            decoration: InputDecoration(
              hintText: context.tr('checker.hint'),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 58),
                child: Icon(Icons.edit_note),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              (context.tr('checker.chipHeadache'), 'Headache'),
              (context.tr('checker.chipCough'), 'Cough'),
              (context.tr('checker.chipNausea'), 'Nausea'),
              (context.tr('checker.chipItchySkin'), 'Itchy skin'),
            ]
                .map(
                  (pair) => ActionChip(
                    label: Text(pair.$1),
                    onPressed:
                        isChecking ? null : () => controller.text = pair.$2,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff153f36),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: isChecking ? null : () => checkSymptoms(),
              icon: isChecking
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward_rounded),
              label: Text(isChecking
                  ? context.tr('checker.analyzing')
                  : context.tr('checker.checkSymptoms')),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: AnimatedBuilder(
              animation: widget.store,
              builder: (context, _) => Text(
                widget.store.isPremium
                    ? context.tr('checker.unlimitedChecks')
                    : '${widget.store.checksRemaining} ${context.tr('checker.freeChecksRemaining')}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
          if (result case final value?) ...[
            const SizedBox(height: 24),
            _ResultCard(result: value),
            if (value.remedies.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(context.tr('checker.helpfulOptions'),
                  style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              ...value.remedies.map(
                (remedy) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: RemedyCard(
                    remedy: remedy,
                  ),
                ),
              ),
            ],
            if (value.remedies.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    context.tr('checker.noMatch'),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 20),
          Text(
            context.tr('market.disclaimer'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final CheckResult result;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: colors.primary),
                const SizedBox(width: 8),
                Text(
                  context.tr('checker.yourGuidance'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              result.possibleCondition,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text('${context.tr('checker.confidence')}: ${result.confidence}%'),
            const SizedBox(height: 10),
            Text(
              context.tr('checker.resultDisclaimer'),
            ),
          ],
        ),
      ),
    );
  }
}
