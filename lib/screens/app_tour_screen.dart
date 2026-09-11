import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTourScreen extends StatefulWidget {
  const AppTourScreen({
    required this.onComplete,
    super.key,
  });

  static const completedKey = 'app_tour_completed';

  final VoidCallback onComplete;

  @override
  State<AppTourScreen> createState() => _AppTourScreenState();
}

class _AppTourScreenState extends State<AppTourScreen> {
  final _pages = const [
    _TourPage(
      icon: Icons.health_and_safety_outlined,
      title: 'Understand your symptoms',
      description:
          'Describe how you feel and explore helpful wellness information and remedies in one place.',
    ),
    _TourPage(
      icon: Icons.local_florist_outlined,
      title: 'Explore trusted remedies',
      description:
          'Browse natural remedies with preparation guidance, safety notes, and warnings to help you make informed choices.',
    ),
    _TourPage(
      icon: Icons.shopping_bag_outlined,
      title: 'Find products and support',
      description:
          'Discover available wellness products, manage your orders, and keep your health information connected to your account.',
    ),
    _TourPage(
      icon: Icons.groups_outlined,
      title: 'Contribute to the community',
      description:
          'Suggest remedies and share useful knowledge. Contributions are reviewed before they appear in the catalog.',
    ),
  ];

  final _controller = PageController();
  var _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(AppTourScreen.completedKey, true);
    if (mounted) widget.onComplete();
  }

  void _next() {
    if (_page == _pages.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Skip'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (page) => setState(() => _page = page),
                itemBuilder: (context, index) => _TourPageView(
                  page: _pages[index],
                  theme: theme,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: index == _page ? 24 : 8,
                  decoration: BoxDecoration(
                    color: index == _page
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(
                    _page == _pages.length - 1 ? 'Get started' : 'Next',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TourPage {
  const _TourPage({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class _TourPageView extends StatelessWidget {
  const _TourPageView({
    required this.page,
    required this.theme,
  });

  final _TourPage page;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/app_icon.png',
            height: 112,
            width: 112,
          ),
          const SizedBox(height: 24),
          Icon(
            page.icon,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
