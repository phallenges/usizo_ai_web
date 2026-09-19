import 'package:flutter/material.dart';

class PremiumBanner extends StatelessWidget {
  const PremiumBanner({
    required this.isPremium,
    required this.onPressed,
    super.key,
  });

  final bool isPremium;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xfffff3d6),
      child: ListTile(
        leading: const Icon(Icons.auto_awesome, color: Color(0xffb46900)),
        title:
            Text(isPremium ? 'UsizoAI Plus is active' : 'Unlock UsizoAI Plus'),
        subtitle: Text(
          isPremium
              ? 'Unlimited health chat and priority guidance.'
              : 'Three research-grounded chat checks each month.',
        ),
        trailing: TextButton(
          onPressed: onPressed,
          child: Text(isPremium ? 'Manage' : 'Upgrade'),
        ),
      ),
    );
  }
}
