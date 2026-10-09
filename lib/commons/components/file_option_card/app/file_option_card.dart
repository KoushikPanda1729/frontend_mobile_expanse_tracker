import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/commons/constants/app_icons.dart';
import 'package:expensetracker/commons/text/app/views/custom_text_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class FileOptionsRow extends StatelessWidget {
  const FileOptionsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 20),
      color: Colors.white,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          FileOptionCard(icon: AppIcons.camera, label: "Camera"),
          FileOptionCard(icon: AppIcons.galleryIcon, label: "Image"),
          FileOptionCard(icon: AppIcons.file, label: "Document"),
        ],
      ),
    );
  }
}

class FileOptionCard extends StatelessWidget {
  final String icon;
  final String label;

  const FileOptionCard({
    super.key,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 107,
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.violet20,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            icon,
            colorFilter: const ColorFilter.mode(
              AppColors.violet100,
              BlendMode.srcIn,
            ),
          ), // Purple icon
          const SizedBox(height: 8),
          Body3(
            text: label,
            color: AppColors.violet100,
          )
        ],
      ),
    );
  }
}
