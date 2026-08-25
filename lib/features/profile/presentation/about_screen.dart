import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/brand_mark.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About & legal')),
      body: ListView(
        padding: const EdgeInsets.all(FgTokens.s6),
        children: [
          const Center(child: BrandMark(size: 88)),
          const SizedBox(height: FgTokens.s4),
          Text('FinGenius AI',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          Text('Intelligent Personal Finance Management\nand Financial Wellness Companion',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center),
          const SizedBox(height: FgTokens.s2),
          Text('Version 1.0.0', style: theme.textTheme.labelMedium, textAlign: TextAlign.center),
          const SizedBox(height: FgTokens.s8),
          _section(context, 'Important disclaimer',
              'FinGenius AI is an educational financial-wellness tool. It is not a bank, broker, '
              'credit-rating service, investment adviser, accountant or tax adviser. AI-generated '
              'content can be wrong; verify important figures before acting. For high-impact '
              'decisions, consult a qualified professional.'),
          _section(context, 'The financial-health score',
              'The 0–100 score is computed on your device from a documented formula (savings rate, '
              'budget adherence, cash-flow stability, emergency fund, bill punctuality). It is a '
              'wellness indicator, not a credit score, and is never shared with third parties.'),
          _section(context, 'Your privacy',
              'Your data lives in your private Firebase space, protected by per-user security rules. '
              'Receipt text is read on-device. AI requests contain aggregated totals only. Analytics '
              'are opt-in and contain no financial values. You can export or delete everything at any time.'),
          _section(context, 'Open-source licences',
              'Built with Flutter and Firebase. Manrope font © The Manrope Project, SIL Open Font '
              'Licence 1.1. Charts by fl_chart (MIT). Full licence texts available via the button below.'),
          const SizedBox(height: FgTokens.s4),
          OutlinedButton(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'FinGenius AI',
              applicationVersion: '1.0.0',
            ),
            child: const Text('View open-source licences'),
          ),
          const SizedBox(height: FgTokens.s6),
          Text('CMP 7003 — Emerging Mobile Applications · Academic project',
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, String body) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: FgTokens.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: FgTokens.s2),
          Text(body, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
