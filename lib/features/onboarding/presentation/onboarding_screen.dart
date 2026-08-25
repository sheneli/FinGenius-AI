import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/brand_mark.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    (Icons.receipt_long, 'Capture effortlessly',
        'Scan receipts, speak an expense, or type it in seconds. FinGenius sorts it for you — and you always have the final say.'),
    (Icons.insights, 'Understand honestly',
        'A transparent financial-health score, real trends and forecasts with honest uncertainty. No magic numbers.'),
    (Icons.auto_awesome, 'Improve gently',
        'Payday-aware nudges, budget alerts and an AI assistant grounded in your own data. Educational guidance — not financial advice.'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: FgTokens.s8),
            const BrandMark(size: 64),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) {
                  final (icon, title, body) = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.all(FgTokens.s8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 80, color: theme.colorScheme.primary),
                        const SizedBox(height: FgTokens.s6),
                        Text(title,
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                            textAlign: TextAlign.center),
                        const SizedBox(height: FgTokens.s3),
                        Text(body,
                            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: FgTokens.dFast,
                  margin: const EdgeInsets.symmetric(horizontal: FgTokens.s1),
                  width: i == _page ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _page ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(FgTokens.rPill),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(FgTokens.s6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: () {
                      if (_page < _pages.length - 1) {
                        _controller.nextPage(duration: FgTokens.dMed, curve: Curves.easeOut);
                      } else {
                        context.go('/signup');
                      }
                    },
                    child: Text(_page < _pages.length - 1 ? 'Next' : 'Get started'),
                  ),
                  TextButton(
                    onPressed: () => context.go('/signin'),
                    child: const Text('I already have an account'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
