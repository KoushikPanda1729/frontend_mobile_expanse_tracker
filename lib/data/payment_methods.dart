import 'package:flutter/material.dart';

/// How a payment was made. The text is saved as the transaction's mode, so it shows next to the category in the lists.
class PayMethod {
  final String mode;
  final IconData icon;
  const PayMethod(this.mode, this.icon);
}

const _upi = PayMethod('UPI', Icons.qr_code_2);
const _card = PayMethod('Card', Icons.credit_card);
const _net = PayMethod('Net banking', Icons.language);
const _cash = PayMethod('Cash', Icons.payments_outlined);
const _wallet = PayMethod('Wallet', Icons.account_balance_wallet_outlined);
const _cheque = PayMethod('Cheque', Icons.receipt_long_outlined);
const _auto = PayMethod('Auto-debit', Icons.autorenew);

/// The methods that make sense for each kind of entry.
List<PayMethod> methodsFor({required bool isIncome, required bool isTransfer}) {
  if (isTransfer) return const [_upi, _net, _cheque, _cash, _wallet];
  if (isIncome) return const [_upi, _net, _cheque, _cash, _wallet];
  return const [_upi, _card, _net, _cash, _wallet, _cheque, _auto];
}

/// Cash and wallet money never appears on a bank statement: the import does not try to match it
/// and it does not change the bank balance.
bool methodInBank(String mode) => mode != 'Cash' && mode != 'Wallet';

/// Quick tags for a single transaction.
const txnTags = ['Friend', 'Family', 'Rent', 'Lent', 'Borrowed', 'Gift', 'Work', 'Trip', 'One-time'];
