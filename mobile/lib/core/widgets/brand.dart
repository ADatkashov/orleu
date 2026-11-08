import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// ORLEU logo mark: rounded gradient square with the lime "O".
class LogoMark extends StatelessWidget {
  final double size;
  const LogoMark({super.key, this.size = 38});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(gradient: AppGradients.logo, borderRadius: BorderRadius.circular(size * 0.34)),
      child: Text(
        'O',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.accentLime, fontWeight: FontWeight.w800, height: 1, fontSize: size * 0.5),
      ),
    ),
  );
}
