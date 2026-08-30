import 'package:flutter/material.dart';

import '../models/remedy.dart';

class RemedyCard extends StatelessWidget {
  const RemedyCard({
    required this.remedy,
    required this.onAdd,
    this.compact = false,
    super.key,
  });

  final Remedy remedy;
  final VoidCallback onAdd;
  final bool compact;

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
                Text(
                  remedy.priceLabel,
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(remedy.description),
            const SizedBox(height: 6),
            Text(
              '${remedy.scientificName} • ${remedy.localNames.values.join(', ')}',
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
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Add to basket'),
            ),
          ],
        ),
      ),
    );
  }
}
