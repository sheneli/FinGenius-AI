import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// Wraps every chart with: a title, an accessible text summary (read by
/// screen readers instead of the pixels), an empty state, and a toggleable
/// data-table alternative — charts are never the only representation.
class ChartContainer extends StatefulWidget {
  const ChartContainer({
    super.key,
    required this.title,
    required this.textSummary,
    required this.chart,
    this.tableAlternative,
    this.isEmpty = false,
    this.emptyMessage = 'Not enough data yet — add a few transactions first.',
  });

  final String title;
  final String textSummary;
  final Widget chart;
  final Widget? tableAlternative;
  final bool isEmpty;
  final String emptyMessage;

  @override
  State<ChartContainer> createState() => _ChartContainerState();
}

class _ChartContainerState extends State<ChartContainer> {
  bool _showTable = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FgTokens.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(widget.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
                if (widget.tableAlternative != null && !widget.isEmpty)
                  IconButton(
                    tooltip: _showTable ? 'Show chart' : 'Show as table',
                    icon: Icon(_showTable ? Icons.show_chart : Icons.table_rows_outlined, size: FgTokens.iconMd),
                    onPressed: () => setState(() => _showTable = !_showTable),
                  ),
              ],
            ),
            const SizedBox(height: FgTokens.s3),
            if (widget.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: FgTokens.s6),
                child: Center(
                  child: Text(widget.emptyMessage,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center),
                ),
              )
            else
              Semantics(
                label: '${widget.title}. ${widget.textSummary}',
                child: ExcludeSemantics(
                  child: _showTable && widget.tableAlternative != null
                      ? widget.tableAlternative!
                      : widget.chart,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
