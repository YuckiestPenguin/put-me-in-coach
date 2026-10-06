import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _seenKey = 'onboarding_seen_v1';

/// Three short slides explaining the app. Shown once on first launch (per
/// device) and again from the Home "How it works" button.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  /// Opens the slides if this device hasn't seen them yet.
  static Future<void> showIfFirstTime(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_seenKey) ?? false) return;
    } catch (_) {
      return;
    }
    if (!context.mounted) return;
    await show(context);
  }

  static Future<void> show(BuildContext context) =>
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Slide {
  final IconData icon;
  final String title;
  final String body;
  const _Slide(this.icon, this.title, this.body);
}

const _slides = [
  _Slide(
    Icons.groups_outlined,
    'Set up your team',
    'Add your players once under Teams. Add a league if you want its rules '
        '(periods, length, players on the field) applied to every game.',
  ),
  _Slide(
    Icons.timer_outlined,
    'Everyone gets their time',
    'The clock tracks how long each player has been on the field. When a '
        'sub is due, the app suggests who has played the least, so playing '
        'time stays fair.',
  ),
  _Slide(
    Icons.sports_soccer,
    'Run the game',
    'Use "Take a break" to pause and "End half" to move to the next period. '
        'You can also keep score and goals. End the game to save a summary '
        'to your history.',
  ),
];

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_seenKey, true);
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  void _next() {
    if (_page == _slides.length - 1) {
      _finish();
    } else {
      _controller.nextPage(
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = _page == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(last ? '' : 'Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  for (final s in _slides)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(s.icon, size: 96, color: scheme.primary),
                          const SizedBox(height: 32),
                          Text(s.title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 16),
                          Text(s.body,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _page ? scheme.primary : scheme.outlineVariant,
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(last ? 'Get started' : 'Next'),
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
