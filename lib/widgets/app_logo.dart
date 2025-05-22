import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final Color? color;

  const AppLogo({super.key, this.size = 80.0, this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.rss_feed, // Using rss_feed icon as a placeholder
      size: size,
      color: color ?? Theme.of(context).colorScheme.primary,
    );
  }
}