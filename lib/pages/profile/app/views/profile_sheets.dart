import 'package:expensetracker/commons/components/sheets/app_sheets.dart';
import 'dart:io';

import 'package:expensetracker/commons/components/button/app/solid_button_widget.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/data/api.dart';
import 'package:expensetracker/data/dues.dart';
import 'package:expensetracker/data/funds.dart';
import 'package:expensetracker/data/auth.dart';
import 'package:expensetracker/data/ledger.dart';
import 'package:expensetracker/data/reminder.dart';
import 'package:expensetracker/data/settings.dart';
import 'package:expensetracker/data/statements.dart';
import 'package:expensetracker/pages/pdf_passwords/pdf_passwords_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

const _sheetShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)));

Future<String?> _pickPhoto(BuildContext context, String? current) async {
  final source = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: _sheetShape,
    builder: (s) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(s, 'gallery'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(s, 'camera'),
          ),
          if (current != null)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.red100),
              title: const Text('Remove photo',
                  style: TextStyle(color: AppColors.red100)),
              onTap: () => Navigator.pop(s, 'remove'),
            ),
        ],
      ),
    ),
  );
  if (source == null) return current; // dismissed
  if (source == 'remove') return '';
  try {
    final f = await ImagePicker()
        .pickImage(
            source: source == 'camera' ? ImageSource.camera : ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    return f?.path ?? current;
  } catch (_) {
    return current; // camera missing on simulator, permission denied, etc.
  }
}

void showAccountSheet(BuildContext context, WidgetRef ref) {
  final p = ref.read(profileProvider);
  final name = TextEditingController(text: p.name);
  final handle = TextEditingController(text: p.handle);
  String? photo = p.photoPath;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: _sheetShape,
    builder: (sheet) => StatefulBuilder(
      builder: (_, setS) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 20, 16, 16 + MediaQuery.of(sheet).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Account',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: () async {
                    final r = await _pickPhoto(sheet, photo);
                    setS(() => photo = (r == null || r.isEmpty) ? null : r);
                  },
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: AppColors.violet20,
                        backgroundImage:
                            photo == null ? null : FileImage(File(photo!)),
                        child: photo != null
                            ? null
                            : Text(
                                name.text.isEmpty
                                    ? '?'
                                    : name.text[0].toUpperCase(),
                                style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.violet100),
                              ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                              color: AppColors.violet100,
                              shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: name,
                decoration: const InputDecoration(
                    labelText: 'Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: handle,
                decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixText: '@',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              SolidButtonWidget(
                label: 'Save',
                onPressed: () async {
                  if (name.text.trim().isEmpty) return;
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await ref.read(profileProvider.notifier).save(
                          name: name.text.trim(),
                          handle: handle.text.trim().replaceAll('@', ''),
                          photoPath: photo,
                        );
                    if (sheet.mounted) Navigator.pop(sheet);
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(
                        content: Text(
                            e is ApiException ? e.message : 'Could not save.')));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void showSettingsSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: _sheetShape,
    builder: (sheet) => Consumer(
      builder: (_, ref, __) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Settings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.violet100,
                title: const Text('Hide balance'),
                subtitle: const Text('Mask the balance on Home'),
                value: ref.watch(hideBalanceProvider),
                onChanged: (v) =>
                    ref.read(hideBalanceProvider.notifier).state = v,
              ),
              Consumer(builder: (ctx, ref, _) {
                final r = ref.watch(reminderProvider);
                final next = nextAlarm(r, DateTime.now());
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.alarm, color: AppColors.violet100),
                  title: const Text('Month-end alarm'),
                  subtitle: Text(next == null
                      ? 'Off. Get reminded to upload your statement'
                      : 'Next: ${shortDate(next)} ${next.year}, '
                          '${TimeOfDay(hour: next.hour, minute: next.minute).format(ctx)}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    final router = GoRouter.of(ctx);
                    Navigator.pop(sheet);
                    router.push('/alarm');
                  },
                );
              }),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.handshake_outlined, color: AppColors.violet100),
                title: const Text('Money to get & pay'),
                subtitle: const Text('Who will pay you, and who you need to pay'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  final router = GoRouter.of(context);
                  Navigator.pop(sheet);
                  router.push('/dues');
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_sweep_outlined, color: AppColors.red100),
                title: const Text('Delete my data',
                    style: TextStyle(color: AppColors.red100)),
                subtitle: const Text('Choose what to delete. Your login stays'),
                onTap: () {
                  Navigator.pop(sheet);
                  _clearAllData(context, ref);
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _errText(Object e) => e is ApiException ? e.message : 'Something went wrong.';

void showSecuritySheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: _sheetShape,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Security',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_outline, color: AppColors.violet100),
              title: const Text('Change password'),
              subtitle: const Text('You will be signed out on every device'),
              onTap: () {
                Navigator.pop(sheet);
                _changePassword(context, ref);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_sweep_outlined, color: AppColors.red100),
              title: const Text('Delete all my data',
                  style: TextStyle(color: AppColors.red100)),
              subtitle: const Text('Choose what to delete. Your login stays'),
              onTap: () {
                Navigator.pop(sheet);
                _clearAllData(context, ref);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final current = TextEditingController();
  final next = TextEditingController();
  final again = TextEditingController();
  String? error;
  final ok = await showAppSheet<bool>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (_, setS) => SheetFrame(
        title: const Text('Change password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current password')),
            TextField(
                controller: next,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'New password', helperText: 'At least 8 characters')),
            TextField(
                controller: again,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password again')),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(error!, style: const TextStyle(color: AppColors.red100)),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (current.text.isEmpty) {
                setS(() => error = 'Enter your current password');
              } else if (next.text.length < 8 || next.text.length > 72) {
                setS(() => error = 'Use 8 to 72 characters');
              } else if (next.text != again.text) {
                setS(() => error = 'The new passwords do not match');
              } else {
                Navigator.pop(d, true);
              }
            },
            child: const Text('Change'),
          ),
        ],
      ),
    ),
  );
  if (ok != true) return;
  try {
    await api.post('/users/me/password',
        body: {'currentPassword': current.text, 'newPassword': next.text});
    // the server signed this account out everywhere
    await ref.read(authProvider.notifier).logout();
    router.go('/login');
    messenger.showSnackBar(
        const SnackBar(content: Text('Password changed. Sign in again.')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(_errText(e))));
  }
}

/// One thing the user can delete.
class _Item {
  final String key; // server scope, or 'phone' for files on this device
  final String title, sub;
  const _Item(this.key, this.title, this.sub);
}

const _items = [
  _Item('transactions', 'Transactions and statements',
      'All transactions, the imported PDFs they came from, and your payee labels'),
  _Item('budgets', 'Budgets', 'Your monthly category limits'),
  _Item('passwords', 'Saved PDF passwords', 'Passwords kept for locked statements'),
  _Item('dues', 'Money to get & pay', 'Your notes on who pays you and who you pay'),
  _Item('funds', 'Mutual funds', 'Your funds and their payments'),
  _Item('photo', 'Profile photo', 'Your name and login stay'),
  _Item('phone', 'Files on this phone', 'Downloaded statement PDFs and cached photos'),
];

/// Lets the user pick what to delete, then removes it from the server
/// (DELETE /users/me/data?scope=...) and from this phone. The account and login always stay.
Future<void> _clearAllData(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final picked = <String>{};
  final ok = await showAppSheet<bool>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (_, setS) {
        final all = picked.length == _items.length;
        return SheetFrame(
          title: const Text('Delete my data'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Choose what to delete. This cannot be undone.'),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppColors.violet100,
                  title: const Text('Select all',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  value: all,
                  onChanged: (v) => setS(() {
                    picked.clear();
                    if (v == true) picked.addAll(_items.map((i) => i.key));
                  }),
                ),
                const Divider(height: 1),
                for (final i in _items)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.violet100,
                    title: Text(i.title),
                    subtitle: Text(i.sub),
                    value: picked.contains(i.key),
                    onChanged: (v) => setS(() {
                      v == true ? picked.add(i.key) : picked.remove(i.key);
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
            TextButton(
              onPressed: picked.isEmpty ? null : () => Navigator.pop(d, true),
              child: Text(
                  picked.isEmpty ? 'Delete' : 'Delete (${picked.length})',
                  style: TextStyle(
                      color: picked.isEmpty ? Colors.grey : AppColors.red100)),
            ),
          ],
        );
      },
    ),
  );
  if (ok != true || picked.isEmpty) return;
  try {
    final scope = picked.where((k) => k != 'phone').toList();
    if (scope.isNotEmpty) {
      await api.request('DELETE', '/users/me/data', query: {'scope': scope.join(',')});
    }
    if (picked.contains('phone')) await clearLocalFiles();
    // reload whatever was touched
    if (picked.contains('transactions')) {
      ref.invalidate(ledgerProvider);
      ref.invalidate(statementsProvider);
      ref.read(monthProvider.notifier).state = null;
      ref.read(filterProvider.notifier).state = const TxnFilter();
    }
    if (picked.contains('budgets')) ref.invalidate(budgetsProvider);
    if (picked.contains('dues')) ref.invalidate(duesProvider);
    if (picked.contains('funds')) {
      ref.invalidate(fundsProvider);
      ref.invalidate(unassignedProvider);
    }
    if (picked.contains('passwords')) ref.invalidate(pdfPasswordsProvider);
    // the profile photo is a local copy of the server one
    if (picked.contains('photo') || picked.contains('phone')) ref.invalidate(profileProvider);
    messenger.showSnackBar(const SnackBar(content: Text('Deleted')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(_errText(e))));
  }
}
