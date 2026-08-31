import 'dart:async';

import 'package:flutter/material.dart';

import '../models/remedy.dart';
import '../services/app_store.dart';
import '../services/symptom_checker.dart';
import '../widgets/premium_banner.dart';
import '../widgets/remedy_card.dart';
import 'emergency_screen.dart';

class SymptomCheckerScreen extends StatefulWidget {
  const SymptomCheckerScreen({
    required this.store,
    required this.remedies,
    required this.checker,
    super.key,
  });

  final AppStore store;
  final List<Remedy> remedies;
  final SymptomChecker checker;

  @override
  State<SymptomCheckerScreen> createState() => _SymptomCheckerScreenState();
}

class _SymptomCheckerScreenState extends State<SymptomCheckerScreen> {
  final controller = TextEditingController();
  CheckResult? result;
  String language = 'English';
  bool isChecking = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void checkSymptoms() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Describe at least one symptom.')),
      );
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
      if (!widget.store.recordCheck()) {
        if (!mounted) return;
        unawaited(showDialog<void>(
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
                  widget.store.setPremium(true);
                  Navigator.pop(context);
                },
                child: const Text('Try Plus'),
              ),
            ],
          ),
        ),
        );
        return;
      }
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
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'UsizoAI',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              DropdownButton<String>(
                value: language,
                underline: const SizedBox.shrink(),
                items: const ['English', 'Shona', 'Ndebele']
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => language = value!),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Private, practical health guidance — even when you are offline.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          AnimatedBuilder(
            animation: widget.store,
            builder: (context, _) => PremiumBanner(
              isPremium: widget.store.isPremium,
              onPressed: () => widget.store.setPremium(!widget.store.isPremium),
            ),
          ),
          const SizedBox(height: 20),
          Text('How are you feeling?', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            minLines: 4,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            enabled: !isChecking,                    decoration: const InputDecoration(
              hintText: 'Example: I have a mild headache since this morning...',
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 58),
                child: Icon(Icons.edit_note),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Headache', 'Cough', 'Nausea', 'Itchy skin']
                .map(
                  (text) => ActionChip(
                    label: Text(text),
                    onPressed: isChecking ? null : () => controller.text = text,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: isChecking ? null : () => checkSymptoms(),
            icon: isChecking
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
            label: Text(isChecking ? 'Analyzing...' : 'Check symptoms'),
          ),
          const SizedBox(height: 10),
          Center(
            child: AnimatedBuilder(
              animation: widget.store,
              builder: (context, _) => Text(
                widget.store.isPremium
                    ? 'Unlimited checks with Plus'
                    : '${widget.store.checksRemaining} free checks remaining',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
          if (result case final value?) ...[
            const SizedBox(height: 24),
            _ResultCard(result: value),
            if (value.remedies.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Helpful options', style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              ...value.remedies.map(
                (remedy) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: RemedyCard(
                    remedy: remedy,
                    onAdd: () {
                      widget.store.addToCart(remedy);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${remedy.name} added.')),
                      );
                    },
                  ),
                ),
              ),
            ],
            if (value.remedies.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No match found. Try describing another symptom, or consult a healthcare professional.',
                  ),
                ),
              ),
          ],
          const SizedBox(height: 20),
          Text(
            'UsizoAI offers general education, not a diagnosis. Seek professional care if symptoms persist or worsen.',
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
                  'Your guidance',
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
            Text('Pattern match confidence: ${result.confidence}%'),
            const SizedBox(height: 10),
            const Text(
              'Rest, hydrate, and monitor your symptoms. This result is not a medical diagnosis.',
            ),
          ],
        ),
      ),
    );
  }
}

