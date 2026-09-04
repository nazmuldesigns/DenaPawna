import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A circular avatar for a person: shows their photo if available,
/// otherwise falls back to the first letter of their name on a
/// deterministic pastel background color.
class PersonAvatar extends StatelessWidget {
  final String name;
  final String? photoPath;
  final double radius;

  const PersonAvatar({
    super.key,
    required this.name,
    this.photoPath,
    this.radius = 22,
  });

  Color _colorForName(String name) {
    final colors = [
      AppColors.teal,
      const Color(0xFF6C63FF),
      const Color(0xFFE0563F),
      const Color(0xFF2E9CCA),
      const Color(0xFFC9911F),
      const Color(0xFF8E44AD),
    ];
    final idx = name.isEmpty ? 0 : name.codeUnitAt(0) % colors.length;
    return colors[idx];
  }

  @override
  Widget build(BuildContext context) {
    if (photoPath != null && File(photoPath!).existsSync()) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(File(photoPath!)),
      );
    }
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: _colorForName(name).withValues(alpha: 0.18),
      child: Text(
        initial,
        style: TextStyle(
          color: _colorForName(name),
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }
}
