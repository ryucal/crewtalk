import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class AvatarWidget extends StatelessWidget {
  final String name;
  final double size;
  final double fontSize;
  final double borderRadius;

  const AvatarWidget({
    super.key,
    required this.name,
    this.size = 48,
    this.fontSize = 20,
    this.borderRadius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.avatarColor(name);
    final label = name.isNotEmpty ? name[0] : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: colors.color,
        ),
      ),
    );
  }
}
