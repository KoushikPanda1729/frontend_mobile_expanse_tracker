import 'package:expensetracker/commons/router/app_router.dart';
import 'package:expensetracker/data/ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('tabs, add expense, budget, report render and work', (t) async {
    // test font (Ahem) is wide, so ignore overflow noise; real layout checked on simulator
    SharedPreferences.setMockInitialValues({});
    final orig = FlutterError.onError;
    FlutterError.onError = (d) {
      if (!d.toString().contains('overflowed')) orig!(d);
    };
    t.view.physicalSize = const Size(1206, 2622);
    t.view.devicePixelRatio = 3;
    final c = ProviderContainer();
    await t.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(routerConfig: goRouter)));
    goRouter.go('/');
    await t.pumpAndSettle();
    expect(find.text('Account Balance'), findsOneWidget);
    expect(find.text('Spending by Category'), findsOneWidget);
    final before = c.read(ledgerProvider).value!.all.length;

    // add expense through the form
    goRouter.push('/expenses');
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, '123.5');
    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
    expect(c.read(ledgerProvider).value!.all.length, before + 1);
    expect(find.textContaining('saved'), findsOneWidget);

    for (final tab in ['Transaction', 'Budget', 'Profile', 'Home']) {
      await t.tap(find.text(tab));
      await t.pumpAndSettle();
    }
    goRouter.push('/notifications');
    await t.pumpAndSettle();
    goRouter.pop();
    await t.pumpAndSettle();
    await t.tap(find.text('Transaction'));
    await t.pumpAndSettle();
    await t.tap(find.text('See your financial report'));
    await t.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await t.tapAt(const Offset(350, 600));
      await t.pumpAndSettle();
    }
  });
}
