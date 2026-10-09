import 'package:expensetracker/commons/components/custom_bottom_sheet/app/open_custom_bottom_sheet.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/commons/constants/app_icons.dart';
import 'package:expensetracker/commons/constants/text_styles.dart';
import 'package:expensetracker/commons/text/app/views/custom_text_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class TextfieldDropdown<T> extends StatelessWidget {
  final String label;
  final String title;
  final String hintText;
  final T selectedItem;
  final List<T> items;
  final bool isDisabled;
  final bool isCircularBorder;
  final ValueChanged<T> onItemSelected;
  final String Function(T) getDisplayText;
  final Widget Function(T)? itemBuilder;

  const TextfieldDropdown({
    super.key,
    required this.label,
    this.title = "",
    required this.hintText,
    required this.selectedItem,
    required this.items,
    required this.onItemSelected,
    required this.getDisplayText,
    this.itemBuilder,
    this.isCircularBorder = false,
    this.isDisabled = false,
  });

  void _openPicker(BuildContext context) {
    openCustomBottomSheet(
      context: context,
      child: items.isNotEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Title3(
                          text: title,
                        ))
                    : const SizedBox.shrink(),
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: 16.0,
                    end: 16.0,
                    top: 12.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: items.map((item) {
                      final bool isSelected = item == selectedItem;
                      return Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    onItemSelected(item);
                                    Navigator.pop(context);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12.0),
                                    child: itemBuilder?.call(item) ??
                                        Body3(
                                          text: getDisplayText(item),
                                          color: isSelected
                                              ? AppColors.violet100
                                              : AppColors.dark100,
                                        ),
                                  ),
                                ),
                                isSelected
                                    ? SvgPicture.asset(
                                        AppIcons.checkIcon,
                                        colorFilter: const ColorFilter.mode(
                                          AppColors.violet100,
                                          BlendMode.srcIn,
                                        ),
                                      )
                                    : const SizedBox()
                              ],
                            ),
                          ),
                          const SizedBox(height: 12.0),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            )
          : SizedBox(
              height: MediaQuery.of(context).size.height * 0.1,
              child: Center(
                child: Body3(
                  text: 'No category available',
                  color: AppColors.dark50,
                ),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label.isEmpty
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Body3(text: label),
                  const SizedBox(height: 8),
                ],
              ),
        TextFormField(
          controller: TextEditingController(text: getDisplayText(selectedItem)),
          readOnly: true,
          enabled: !isDisabled,
          onTap: () => _openPicker(context),
          style: TextStyles.body3(),
          decoration: InputDecoration(
            isCollapsed: true,
            contentPadding: const EdgeInsetsDirectional.symmetric(
              vertical: 12.0,
              horizontal: 16.0,
            ),
            hintText: hintText,
            hintStyle: TextStyles.body3(
              color: AppColors.dark25,
            ),
            border: OutlineInputBorder(
              borderRadius: isCircularBorder
                  ? BorderRadius.circular(30.0)
                  : BorderRadius.circular(8.0),
              borderSide: const BorderSide(
                color: AppColors.dark25,
                width: 1.0,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: isCircularBorder
                  ? BorderRadius.circular(30.0)
                  : BorderRadius.circular(8.0),
              borderSide: const BorderSide(
                color: AppColors.dark25,
                width: 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: isCircularBorder
                  ? BorderRadius.circular(30.0)
                  : BorderRadius.circular(8.0),
              borderSide: const BorderSide(
                color: AppColors.violet100,
                width: 1.0,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: isCircularBorder
                  ? BorderRadius.circular(30.0)
                  : BorderRadius.circular(8.0),
              borderSide: const BorderSide(
                color: AppColors.red100,
                width: 1.0,
              ),
            ),
            suffixIcon: Padding(
              padding: const EdgeInsetsDirectional.only(end: 16.0),
              child: SizedBox(
                width: 18.0,
                height: 18.0,
                child: SvgPicture.asset(
                  AppIcons.arrowDown2Icon,
                  height: 18.0,
                  width: 18.0,
                ),
              ),
            ),
            suffixIconConstraints: const BoxConstraints(
              maxHeight: 18.0,
              maxWidth: 34.0,
            ),
          ),
        ),
      ],
    );
  }
}
