import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// Bar chart drawn from real series only (no placeholder data). Bars grow in once; [highlight] emphasises
/// one bar (e.g. today or the busiest hour). [labels] are optional x-axis captions shown under the bars.
class AnalyticsBarChart extends StatelessWidget {
  final List<double> values;
  final List<String>? labels;
  final int? highlight;
  final double height;
  final String semanticLabel;
  final Key? chartKey;
  const AnalyticsBarChart({super.key, required this.values, this.labels, this.highlight, this.height = 120, required this.semanticLabel, this.chartKey});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context);
    final maxV = values.fold<double>(0, (a, v) => v > a ? v : a);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      label: semanticLabel, image: true,
      child: ExcludeSemantics(
        child: Column(children: [
          SizedBox(
            height: height, width: double.infinity,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: reduce ? 1 : 0, end: 1),
              duration: AppMotion.slow, curve: AppMotion.curve,
              builder: (_, progress, _) => CustomPaint(
                key: chartKey,
                painter: _BarsPainter(values, maxV, p.chartBar, p.chartBarMuted, p.chartHighlight, p.chartGrid, highlight, progress),
              ),
            ),
          ),
          if (labels != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              for (var i = 0; i < labels!.length; i++)
                Expanded(child: Text(labels![i], textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.clip,
                    style: t.textTheme.labelSmall?.copyWith(color: i == highlight ? t.colorScheme.onSurface : null, fontWeight: i == highlight ? FontWeight.w800 : FontWeight.w500))),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  final List<double> values;
  final double maxValue;
  final Color color, muted, accent, grid;
  final int? highlight;
  final double progress;
  _BarsPainter(this.values, this.maxValue, this.color, this.muted, this.accent, this.grid, this.highlight, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final gridPaint = Paint()..color = grid..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y.clamp(0.5, size.height - 0.5)), Offset(size.width, y.clamp(0.5, size.height - 0.5)), gridPaint);
    }
    final slot = size.width / values.length;
    final w = (slot * 0.62).clamp(2.0, 28.0);
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      final full = maxValue <= 0 || v <= 0 ? 2.0 : (v / maxValue * (size.height - 4)).clamp(4.0, size.height);
      final h = 2 + (full - 2) * progress;
      final paint = Paint()..color = highlight == null ? color : (highlight == i ? accent : color.withValues(alpha: 0.55));
      if (v <= 0) paint.color = muted;
      final x = i * slot + (slot - w) / 2;
      canvas.drawRRect(RRect.fromRectAndCorners(Rect.fromLTWH(x, size.height - h, w, h), topLeft: Radius.circular(w / 2.4), topRight: Radius.circular(w / 2.4), bottomLeft: const Radius.circular(2), bottomRight: const Radius.circular(2)), paint);
    }
  }

  @override
  bool shouldRepaint(_BarsPainter o) => o.values != values || o.maxValue != maxValue || o.highlight != highlight || o.progress != progress || o.color != color;
}
