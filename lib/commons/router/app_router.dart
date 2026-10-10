import 'package:expensetracker/pages/add_transaction/add_transaction_page.dart';
import 'package:expensetracker/pages/alarm/alarm_page.dart';
import 'package:expensetracker/pages/analysis/analysis_page.dart';
import 'package:expensetracker/pages/export/export_page.dart';
import 'package:expensetracker/pages/import_statement/import_page.dart';
import 'package:expensetracker/pages/login/app/views/login_page.dart';
import 'package:expensetracker/pages/main_screen/main_screen.dart';
import 'package:expensetracker/pages/onboarding_page/app/views/onboarding_page.dart';
import 'package:expensetracker/pages/pdf_passwords/pdf_passwords_page.dart';
import 'package:expensetracker/pages/review/review_page.dart';
import 'package:expensetracker/pages/statements/statements_page.dart';
import 'package:expensetracker/pages/sign_up/app/views/signup_page.dart';
import 'package:expensetracker/pages/onboarding_page/app/views/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:expensetracker/pages/notification/app/view/notification_page.dart';

final goRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return const MainScreen();
      },
      routes: [
        GoRoute(
          path: '/',
          name: "home",
          builder: (context, state) => const SizedBox(),
        ),
      ],
    ),
    GoRoute(
      name: 'import',
      path: '/import',
      builder: (context, state) => const ImportPage(),
    ),
    GoRoute(
      name: 'review',
      path: '/review',
      builder: (context, state) => const ReviewPage(),
    ),
    GoRoute(
      name: 'statements',
      path: '/statements',
      builder: (context, state) => const StatementsPage(),
    ),
    GoRoute(
      name: 'pdfPasswords',
      path: '/pdf-passwords',
      builder: (context, state) => const PdfPasswordsPage(),
    ),
    GoRoute(
      name: 'export',
      path: '/export',
      builder: (context, state) => const ExportPage(),
    ),
    GoRoute(
      name: 'alarm',
      path: '/alarm',
      builder: (context, state) => const AlarmPage(),
    ),
    GoRoute(
      name: 'analysis',
      path: '/analysis',
      builder: (context, state) => const AnalysisPage(),
    ),
    GoRoute(
      name: 'splash',
      path: '/splash',
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      name: 'onboarding',
      path: '/onboarding',
      builder: (context, state) => const OnboardingPage(),
    ),
    GoRoute(
      name: 'notifications',
      path: '/notifications',
      builder: (context, state) => const NotificationPage(),
    ),
    GoRoute(
      name: 'expenses',
      path: '/expenses',
      builder: (context, state) => const AddTransactionPage(kind: TxnKind.expense),
    ),
    GoRoute(
      name: 'income',
      path: '/income',
      builder: (context, state) => const AddTransactionPage(kind: TxnKind.income),
    ),
    GoRoute(
      name: 'signup',
      path: '/signup',
      builder: (context, state) => const SignupPage(),
    ),
    GoRoute(
      name: 'transfer',
      path: '/transfer',
      builder: (context, state) => const AddTransactionPage(kind: TxnKind.transfer),
    ),
    GoRoute(
      name: 'login',
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
  ],
);
