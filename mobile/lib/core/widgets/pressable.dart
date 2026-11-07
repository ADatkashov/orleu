import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// Subtle press feedback (scale down) for tappable surfaces. Respects "reduce motion".
class Pressable extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final double scale;
  const Pressable({super.key, required this.child, this.enabled = true, this.scale = 0.98});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  void _set(bool v) {
    if (widget.enabled && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(scale: _down && !reduce ? widget.scale : 1, duration: AppMotion.fast, curve: AppMotion.curve, child: widget.child),
    );
  }
}

/// Fades and lifts its child in once. [index] staggers list items (capped) so lists feel alive but stay fast.
class Entrance extends StatelessWidget {
  final Widget child;
  final int index;
  const Entrance({super.key, required this.child, this.index = 0});
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    final delay = Duration(milliseconds: (index.clamp(0, 6)) * 40);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.slow + delay,
      curve: Interval(delay.inMilliseconds / (AppMotion.slow + delay).inMilliseconds, 1, curve: AppMotion.curve),
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 10), child: c),
      ),
      child: child,
    );
  }
}
