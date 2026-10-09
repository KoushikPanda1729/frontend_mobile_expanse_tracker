import 'package:flutter/material.dart';
import 'package:expensetracker/commons/router/app_router.dart';
import 'package:expensetracker/data/reminder.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  await initReminders();

  runApp(
    const ProviderScope(
      child: MyAppRouter(),
    ),
  );
}

class MyAppRouter extends StatelessWidget {
  const MyAppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return MaterialApp.router(
      routerConfig: goRouter,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.white,
      ),
    );
  }
}
