import 'package:expensetracker/commons/components/button/app/outline_button_widget.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/commons/constants/app_icons.dart';
import 'package:flutter/material.dart';

class OpenCustomDropdown extends StatelessWidget {
  final String currentMonth;
  final String? title;
  final List<String> items;
  final ValueChanged<String> onItemSelected;

  const OpenCustomDropdown({
    super.key,
    required this.currentMonth,
    required this.items,
    this.title,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _openBottomSheet(context);
      },
      child: OutlineButtonWidget(
        label: currentMonth,
        onPressed: null,
        isLeadingIcon: true,
        isCircle: true,
        iconPath: AppIcons.arrowDown2Icon,
        borderColor: AppColors.violet20,
        iconColor: AppColors.violet100,
      ),
    );
  }

  void _openBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                if (title != null) const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        title: Text(item),
                        trailing: currentMonth == item
                            ? const Icon(
                                Icons.check,
                                color: AppColors.violet100,
                              )
                            : null,
                        onTap: () {
                          onItemSelected(item);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
