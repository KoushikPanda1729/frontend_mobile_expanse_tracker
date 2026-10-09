import 'dart:io';

import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/data/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Round avatar with the user's photo, or their initial when no photo is set.
class ProfileAvatar extends ConsumerWidget {
  final double size;
  const ProfileAvatar({super.key, required this.size});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider);
    final photo = p.photoPath;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.violet40, AppColors.violet80],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.violet20,
          image: photo == null
              ? null
              : DecorationImage(image: FileImage(File(photo)), fit: BoxFit.cover),
        ),
        child: photo != null
            ? null
            : Center(
                child: Text(
                  p.name.isEmpty ? '?' : p.name[0].toUpperCase(),
                  style: TextStyle(
                    color: AppColors.violet100,
                    fontWeight: FontWeight.bold,
                    fontSize: size * 0.4,
                  ),
                ),
              ),
      ),
    );
  }
}
