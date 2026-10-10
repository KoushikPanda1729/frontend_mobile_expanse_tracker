import 'package:expensetracker/data/ledger.dart';
import 'package:expensetracker/data/statement_import.dart';
import 'package:flutter_test/flutter_test.dart';

Txn t(String date, double amount, {bool income = false, String mode = 'UPI', String cat = 'Food'}) => Txn(
      date: DateTime.parse(date),
      merchant: 'X',
      mode: mode,
      category: categoryByName(cat),
      amount: amount,
      isIncome: income,
    );

void main() {
  group('Txn', () {
    test('reads an API row, including note, label and bank details', () {
      final x = Txn.fromApi({
        'id': 'abc',
        'date': '2026-09-30',
        'merchant': 'MOUSUMIB',
        'mode': 'UPI',
        'category': 'Shopping',
        'amount': 100,
        'isIncome': false,
        'ref': '627368717033',
        'upiId': '9876543210',
        'bank': 'UTIB',
        'description': 'UPI/DR/...',
        'note': 'tea',
        'label': 'Work',
      });
      expect(x.date, DateTime(2026, 9, 30));
      expect(x.category.name, 'Shopping');
      expect(x.phone, '9876543210'); // a mobile number
      expect(x.subtitle, 'Shopping · UPI · Work');
    });

    test('a 10-digit id that does not start with 6-9 is an account number, not a phone', () {
      final x = Txn(
          date: DateTime(2026, 9, 1), merchant: 'X', mode: 'UPI', category: categoryByName('Transfer'),
          amount: 1, isIncome: false, upiId: '1331010249');
      expect(x.phone, isNull);
    });

    test('cash and wallet entries are not in the bank', () {
      expect(t('2026-10-01', 5, mode: 'Cash').inBank, isFalse);
      expect(t('2026-10-01', 5, mode: 'Wallet').inBank, isFalse);
      expect(t('2026-10-01', 5, mode: 'UPI').inBank, isTrue);
    });
  });

  group('Ledger', () {
    final l = Ledger([
      t('2026-07-05', 100),
      t('2026-08-10', 200, income: true),
      t('2026-09-12', 50),
      t('2026-09-30', 30, mode: 'Cash'), // spending, but not from the bank account
    ], 1000);

    test('months, newest last', () => expect(l.monthKeys, [202607, 202608, 202609]));

    test('one month, all time, and the last N months', () {
      expect(l.inMonth(202609), hasLength(2));
      expect(l.inMonth(Ledger.allTime), hasLength(4));
      expect(l.inMonth(-2), hasLength(3)); // Aug and Sep
      expect(l.inMonth(-6), hasLength(4));
    });

    test('balance follows the bank only', () {
      // 1000 - 100 (Jul) + 200 (Aug) - 50 (Sep); the 30 cash payment is ignored
      expect(l.balanceAtEnd(202609), 1050);
      expect(l.balanceAtEnd(202607), 900);
      expect(l.balanceAtEnd(Ledger.allTime), 1050);
    });

    test('an empty ledger still has a month, so screens never crash', () {
      const empty = Ledger([], 0);
      expect(empty.monthKeys, hasLength(1));
      expect(empty.inMonth(empty.monthKeys.last), isEmpty);
      expect(empty.inMonth(Ledger.allTime), isEmpty);
      expect(empty.inMonth(-3), isEmpty);
    });
  });

  group('formatting', () {
    test('rupees use Indian digit grouping', () {
      expect(inr(1234567.5), '₹12,34,567.50');
      expect(inr(134.95), '₹134.95');
      expect(inr(-41359.39), '-₹41,359.39');
      expect(inr(100), '₹100');
    });

    test('period labels', () {
      expect(monthLabel(202609), 'September');
      expect(monthLabel(Ledger.allTime), 'All time');
      expect(monthLabel(-3), 'Last 3 months');
    });
  });

  group('import review', () {
    test('reads the changes and matches the server sends', () {
      final p = StatementPreview.fromApi({
        'alreadyUploaded': true,
        'transactionCount': 101,
        'newCount': 0,
        'duplicateCount': 101,
        'periodStart': '2026-09-01',
        'periodEnd': '2026-09-30',
        'income': 10,
        'expense': 20,
        'sample': [],
        'manualMatches': [
          {
            'manualId': 'm1',
            'key': 'r:1:e',
            'daysApart': 1,
            'manual': {'date': '2026-09-01', 'name': 'Tea', 'category': 'Food', 'amount': 130, 'isIncome': false, 'note': null, 'label': 'Work'},
            'bank': {'date': '2026-09-02', 'name': 'Abhishek', 'category': 'Transfer', 'amount': 130, 'description': 'UPI', 'upiId': 'x', 'ref': '1'},
          }
        ],
        'changes': [
          {
            'id': 'c1',
            'key': 'r:2:e',
            'signature': 'sig',
            'isIncome': false,
            'fields': ['name', 'amount'],
            'yours': {'date': '2026-09-30', 'name': 'MOUSUMIBEEEEE', 'category': 'Shopping', 'amount': 999},
            'bank': {'date': '2026-09-30', 'name': 'MOUSUMIB', 'category': 'Shopping', 'amount': 100},
          }
        ],
      });
      expect(p.alreadyUploaded, isTrue);
      expect(p.matches.single.daysApart, 1);
      expect(p.matches.single.label, 'Work');
      expect(p.changes.single.fields, ['name', 'amount']);
      expect(p.changes.single.signature, 'sig');
      expect(p.changes.single.bankAmount, 100);
    });
  });
}
