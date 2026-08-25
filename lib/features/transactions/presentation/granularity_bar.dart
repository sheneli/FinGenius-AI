import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../domain/period.dart';

/// The Day / Week / Month / Year filter, shared by the dashboard breakdown and
/// every report chart so they behave identically.
///
/// `showSelectedIcon: false` is load-bearing, not cosmetic: the default
/// checkmark is laid out *inside* the selected segment, stealing ~24dp from a
/// quarter-width slot and forcing the longest labels ("Month", "Year") to wrap
/// onto a second line. Dropping it gives every label a full single line at any
/// font scale. Selection stays distinguishable without relying on colour alone
/// — the chosen segment is both filled and rendered in a heavier weight, and
/// SegmentedButton still exposes `selected` to screen readers.
class GranularityBar extends StatelessWidget {
  const GranularityBar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final PeriodGranularity selected;
  final ValueChanged<PeriodGranularity> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<PeriodGranularity>(
        showSelectedIcon: false,
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: FgTokens.s1)),
          textStyle: WidgetStateProperty.resolveWith((states) {
            final base = theme.textTheme.labelMedium;
            return states.contains(WidgetState.selected)
                ? base?.copyWith(fontWeight: FontWeight.w800)
                : base?.copyWith(fontWeight: FontWeight.w500);
          }),
        ),
        segments: [
          for (final g in PeriodGranularity.values)
            ButtonSegment(
              value: g,
              label: Text(
                g.label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
              ),
            ),
        ],
        selected: {selected},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}
