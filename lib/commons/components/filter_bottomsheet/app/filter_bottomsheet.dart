import 'package:expensetracker/commons/components/button/app/outline_button_widget.dart';
import 'package:expensetracker/commons/components/button/app/solid_button_widget.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/commons/text/app/views/custom_text_library.dart';
import 'package:expensetracker/data/ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FilterBottomSheet extends ConsumerStatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  ConsumerState<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<FilterBottomSheet> {
  late final TxnFilter _initial = ref.read(filterProvider);
  late String? selectedFilter = _initial.type;
  late String? selectedSort = _initial.sort;
  late List<String> selectedCategories = _initial.categories.toList();
  bool showAllCategories = false;

  void toggleFilter(String filter) {
    setState(() {
      selectedFilter = selectedFilter == filter ? null : filter;
    });
  }

  void toggleSort(String sort) {
    setState(() {
      selectedSort = selectedSort == sort ? null : sort;
    });
  }

  void toggleCategory(String category) {
    setState(() {
      if (selectedCategories.contains(category)) {
        selectedCategories.remove(category);
      } else {
        selectedCategories.add(category);
      }
    });
  }

  void resetFilters() {
    setState(() {
      selectedFilter = null;
      selectedSort = null;
      selectedCategories.clear();
      showAllCategories = false;
    });
    ref.read(filterProvider.notifier).state =
        TxnFilter(query: _initial.query);
  }

  @override
  Widget build(BuildContext context) {
    final categories = [for (final c in [...expenseCategories, ...incomeCategories]) c.name];
    List<String> visibleCategories =
        showAllCategories ? categories : categories.take(5).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        color: Colors.white,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Title3(text: "Filter Transaction"),
              SizedBox(
                height: 32,
                width: 71,
                child: SolidButtonWidget(
                  label: "Reset",
                  onPressed: resetFilters,
                  backgroundColor: AppColors.violet20,
                  labelColor: AppColors.violet100,
                  isCircle: true,
                ),
              )
            ],
          ),
          const SizedBox(height: 10),
          Body3(text: "Filter By"),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: [
            filterButton("Income"),
            filterButton("Expense"),
          ]),
          const SizedBox(height: 16),
          Body3(text: "Sort By"),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: [
            sortButton("Highest"),
            sortButton("Lowest"),
            sortButton("Newest"),
            sortButton("Oldest"),
          ]),
          const SizedBox(height: 16),
          Body3(text: "Category"),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: [
            ...visibleCategories.map((category) => categoryButton(category)),
            SizedBox(
              width: 98,
              height: 42,
              child: SolidButtonWidget(
                label: showAllCategories ? "See Less" : "See All",
                onPressed: () {
                  setState(() {
                    showAllCategories = !showAllCategories;
                  });
                },
                backgroundColor: AppColors.violet20,
                labelColor: AppColors.violet100,
                isCircle: true,
              ),
            ),
          ]),
          const SizedBox(height: 16),
          SolidButtonWidget(
            label: "Apply",
            onPressed: () {
              ref.read(filterProvider.notifier).state = TxnFilter(
                type: selectedFilter,
                sort: selectedSort,
                categories: selectedCategories.toSet(),
                query: _initial.query,
              );
              Navigator.pop(context);
            },
          )
        ],
      ),
    );
  }

  Widget filterButton(String label) {
    bool isSelected = selectedFilter == label;
    return SizedBox(
      width: 98,
      height: 42,
      child: isSelected
          ? SolidButtonWidget(
              label: label,
              onPressed: () => toggleFilter(label),
              backgroundColor: AppColors.violet20,
              labelColor: AppColors.violet100,
            )
          : OutlineButtonWidget(
              label: label,
              onPressed: () => toggleFilter(label),
            ),
    );
  }

  Widget sortButton(String label) {
    bool isSelected = selectedSort == label;
    return SizedBox(
      width: 98,
      height: 42,
      child: isSelected
          ? SolidButtonWidget(
              label: label,
              onPressed: () => toggleSort(label),
              backgroundColor: AppColors.violet20,
              labelColor: AppColors.violet100,
            )
          : OutlineButtonWidget(
              label: label,
              onPressed: () => toggleSort(label),
            ),
    );
  }

  Widget categoryButton(String label) {
    bool isSelected = selectedCategories.contains(label);
    return SizedBox(
      width: 98,
      height: 42,
      child: isSelected
          ? SolidButtonWidget(
              label: label,
              onPressed: () => toggleCategory(label),
              backgroundColor: AppColors.violet20,
              labelColor: AppColors.violet100,
            )
          : OutlineButtonWidget(
              label: label,
              onPressed: () => toggleCategory(label),
            ),
    );
  }
}
