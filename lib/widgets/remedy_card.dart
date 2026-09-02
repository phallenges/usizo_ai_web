import 'package:flutter/material.dart';

import '../models/remedy.dart';

/// Displays a single remedy as a guidance card.
///
/// Used in the symptom checker results to show matched remedies
/// with preparation, dosage, and safety info.
class RemedyCard extends StatelessWidget {
  const RemedyCard({
    required this.remedy,
    this.languageCode = 'en',
    this.onTap,
    this.compact = false,
    super.key,
  });

  final Remedy remedy;
  final String languageCode;
  final VoidCallback? onTap;
  final bool compact;

  String get _localName {
    return remedy.localNames[languageCode] ??
        remedy.localNames['en'] ??
        remedy.name;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: colors.primaryContainer,
                  child: Icon(Icons.spa_outlined, color: colors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    remedy.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(remedy.description),
            const SizedBox(height: 6),
            Text(
              '${remedy.scientificName} • $_localName',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (!compact) ...[
              const SizedBox(height: 8),
              Text(
                'Use: ${remedy.usage}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Safety: ${remedy.warning}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 4),
              Text('Preparation: ${remedy.preparation}'),
              const SizedBox(height: 4),
              Text('Dosage: ${remedy.dosage}'),
              const SizedBox(height: 4),
              Text('Evidence: ${remedy.evidenceSource}'),
            ],
            if (onTap != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: onTap,
                icon: const Icon(Icons.info_outline),
                label: const Text('Learn more'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
