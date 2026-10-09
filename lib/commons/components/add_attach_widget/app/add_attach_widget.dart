import 'package:expensetracker/commons/components/custom_bottom_sheet/app/open_custom_bottom_sheet.dart';
import 'package:expensetracker/commons/components/file_option_card/app/file_option_card.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:flutter/material.dart';

class AddAttachWidget extends StatelessWidget {
  const AddAttachWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        openCustomBottomSheet(context: context, child: const FileOptionsRow());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.dark25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.attach_file, color: AppColors.dark25, size: 20),
            const SizedBox(width: 8),
            Text(
              'Add attachment',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
