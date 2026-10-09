import 'dart:io';

import 'package:expensetracker/commons/components/button/app/solid_button_widget.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/data/ledger.dart';
import 'package:expensetracker/data/reminder.dart';
import 'package:expensetracker/data/settings.dart';
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
                onPressed: () {
                  if (name.text.trim().isEmpty) return;
                  ref.read(profileProvider.notifier).state = Profile(
                    name.text.trim(),
                    handle.text.trim().replaceAll('@', ''),
                    photoPath: photo,
                  );
                  Navigator.pop(sheet);
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
                leading: const Icon(Icons.restart_alt, color: AppColors.red100),
                title: const Text('Reset to sample data',
                    style: TextStyle(color: AppColors.red100)),
                subtitle: const Text('Deletes imported and added transactions'),
                onTap: () => showDialog<void>(
                  context: sheet,
                  builder: (d) => AlertDialog(
                    title: const Text('Reset data?'),
                    content: const Text(
                        'Imported and manually added transactions will be removed.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(d),
                          child: const Text('Cancel')),
                      TextButton(
                        onPressed: () {
                          ref.read(ledgerProvider.notifier).reset();
                          ref.read(monthProvider.notifier).state = null;
                          Navigator.pop(d);
                          Navigator.pop(sheet);
                        },
                        child: const Text('Reset',
                            style: TextStyle(color: AppColors.red100)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
