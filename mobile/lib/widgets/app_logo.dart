import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  final double iconSize;
  final double titleSize;

  const AppLogo({
    super.key,
    this.iconSize = 80,
    this.titleSize = 34,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.photo_camera_rounded,
          size: iconSize,
          color: AppTheme.primaryColor,
        ),

        const SizedBox(height: 20),

        Text(
          "SnapSync AI",
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: titleSize,
                fontWeight: FontWeight.bold,
              ),
        ),

        const SizedBox(height: 8),

        Text(
          "Share. Organize. Remember.",
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}