import 'package:expensetracker/commons/components/menu_item/app/menu_item.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/commons/constants/app_icons.dart';
import 'package:expensetracker/data/auth.dart';
import 'package:expensetracker/data/ledger.dart';
import 'package:expensetracker/commons/components/profile_avatar/profile_avatar.dart';
import 'package:expensetracker/data/settings.dart';
import 'package:expensetracker/pages/profile/app/views/profile_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';

bool _loggingOut = false;

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    _buildProfileInfo(
                      ref.watch(profileProvider),
                      () => showAccountSheet(context, ref),
                    ),
                    const SizedBox(height: 24),
                    _buildStats(ref),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.light20.withOpacity(0.1),
                        border: Border.all(
                            color: AppColors.dark100.withOpacity(0.1),
                            width: 1),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(18),
                        ),
                      ),
                      child: Column(
                        children: [
                          MenuItem(
                            icon: AppIcons.wallet3Icon,
                            title: 'Account',
                            subtitle: 'Manage your account',
                            iconColor: AppColors.violet100,
                            onTap: () => showAccountSheet(context, ref),
                          ),
                          Divider(
                            thickness: 1,
                            color: AppColors.dark100.withOpacity(0.1),
                          ),
                          MenuItem(
                            icon: AppIcons.settingsIcon,
                            title: 'Settings',
                            subtitle: 'App settings & preferences',
                            iconColor: AppColors.violet100,
                            onTap: () => showSettingsSheet(context, ref),
                          ),
                          Divider(
                            thickness: 1,
                            color: AppColors.dark100.withOpacity(0.1),
                          ),

                          MenuItem(
                            icon: AppIcons.pieChartIcon,
                            title: 'Full Analysis',
                            subtitle: 'Insights from your statement',
                            iconColor: AppColors.violet100,
                            onTap: () => context.push('/analysis'),
                          ),
                          Divider(
                            thickness: 1,
                            color: AppColors.dark100.withOpacity(0.1),
                          ),
                          MenuItem(
                            icon: AppIcons.downloadIcon,
                            title: 'Import Statement',
                            subtitle: 'Load your SBI statement PDF',
                            iconColor: AppColors.violet100,
                            onTap: () => context.push('/import'),
                          ),
                          Divider(
                            thickness: 1,
                            color: AppColors.dark100.withOpacity(0.1),
                          ),
                          MenuItem(
                            icon: AppIcons.currencyExchangeIcon,
                            title: 'Mutual funds',
                            subtitle: 'What you hold and how much you put in',
                            iconColor: AppColors.violet100,
                            onTap: () => context.push('/funds'),
                          ),
                          Divider(
                            thickness: 1,
                            color: AppColors.dark100.withOpacity(0.1),
                          ),
                          MenuItem(
                            icon: AppIcons.warningIcon,
                            title: 'Check your money',
                            subtitle: 'Payments you may not recognise',
                            iconColor: AppColors.violet100,
                            onTap: () => context.push('/review'),
                          ),
                          Divider(
                            thickness: 1,
                            color: AppColors.dark100.withOpacity(0.1),
                          ),
                          MenuItem(
                            icon: AppIcons.file,
                            title: 'My Statements',
                            subtitle: 'Download or delete imported PDFs',
                            iconColor: AppColors.violet100,
                            onTap: () => context.push('/statements'),
                          ),
                          Divider(
                            thickness: 1,
                            color: AppColors.dark100.withOpacity(0.1),
                          ),
                          MenuItem(
                            icon: AppIcons.settingsIcon,
                            title: 'PDF Passwords',
                            subtitle: 'Saved passwords for locked statements',
                            iconColor: AppColors.violet100,
                            onTap: () => context.push('/pdf-passwords'),
                          ),
                          Divider(
                            thickness: 1,
                            color: AppColors.dark100.withOpacity(0.1),
                          ),
                          MenuItem(
                            icon: AppIcons.settingsIcon,
                            title: 'Security',
                            subtitle: 'Change password, delete your data',
                            iconColor: AppColors.violet100,
                            onTap: () => showSecuritySheet(context, ref),
                          ),
                          Divider(
                            thickness: 1,
                            color: AppColors.dark100.withOpacity(0.1),
                          ),
                          MenuItem(
                            icon: AppIcons.uploadIcon,
                            title: 'Export Data',
                            subtitle: 'Download as CSV or PDF, by date range',
                            iconColor: AppColors.violet100,
                            onTap: () => context.push('/export'),
                          ),
                          Divider(
                            thickness: 1,
                            color: AppColors.dark100.withOpacity(0.1),
                          ),
                          MenuItem(
                            icon: AppIcons.logoutIcon,
                            title: 'Logout',
                            subtitle: 'Sign out of your account',
                            iconColor: AppColors.red100,
                            isLogout: true,
                            onTap: () async {
                              if (_loggingOut) return; // a second tap while signing out does nothing
                              _loggingOut = true;
                              try {
                                await ref.read(authProvider.notifier).logout();
                                if (context.mounted) context.go('/onboarding');
                              } finally {
                                _loggingOut = false;
                              }
                            },
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(WidgetRef ref) {
    final l = ref.watch(ledgerProvider).valueOrNull;
    final income = l == null ? 0.0 : Ledger.income(l.all);
    final expense = l == null ? 0.0 : Ledger.expense(l.all);
    Widget tile(String label, String value, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(value,
                      style: TextStyle(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        );
    return Row(
      children: [
        tile('Total income', inr(income), AppColors.green100),
        const SizedBox(width: 10),
        tile('Total spent', inr(expense), AppColors.red100),
        const SizedBox(width: 10),
        tile('Saved', inr(income - expense), AppColors.violet100),
      ],
    );
  }

  Widget _buildProfileInfo(Profile profile, VoidCallback onEdit) {
    return Row(
      children: [
        const ProfileAvatar(size: 80),
        const SizedBox(width: 19),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '@${profile.handle}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              profile.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const Spacer(),
        GestureDetector(
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: SvgPicture.asset(AppIcons.editIcon),
          ),
        )
      ],
    );
  }
}
