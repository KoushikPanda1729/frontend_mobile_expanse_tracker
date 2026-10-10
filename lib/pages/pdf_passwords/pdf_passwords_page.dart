import 'package:expensetracker/commons/components/sheets/app_sheets.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/data/api.dart';
import 'package:expensetracker/data/ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SavedPassword {
  final String id, label;
  final DateTime? lastUsedAt;
  const SavedPassword(this.id, this.label, this.lastUsedAt);
}

/// GET /pdf-passwords: labels only, the server never sends the passwords back.
final pdfPasswordsProvider =
    FutureProvider.autoDispose<List<SavedPassword>>((ref) async {
  final j = await api.get('/pdf-passwords') as Map<String, dynamic>;
  return [
    for (final m in j['items'] as List)
      SavedPassword(
        (m as Map<String, dynamic>)['id'] as String,
        m['label'] as String,
        m['lastUsedAt'] == null ? null : DateTime.parse(m['lastUsedAt'] as String).toLocal(),
      )
  ];
});

/// Passwords for locked bank PDFs. They are tried automatically on every import.
class PdfPasswordsPage extends ConsumerWidget {
  const PdfPasswordsPage({super.key});

  String _err(Object e) => e is ApiException ? e.message : 'Something went wrong.';

  /// Add (when [p] is null) or change a saved password.
  Future<void> _form(BuildContext context, WidgetRef ref, [SavedPassword? p]) async {
    final messenger = ScaffoldMessenger.of(context);
    final label = TextEditingController(text: p?.label ?? '');
    final pw = TextEditingController();
    var hide = true;
    final ok = await showAppSheet<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (_, setS) => SheetFrame(
          title: Text(p == null ? 'Add password' : 'Edit password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: label,
                decoration: const InputDecoration(
                    labelText: 'Name', hintText: 'e.g. SBI savings'),
              ),
              TextField(
                controller: pw,
                obscureText: hide,
                decoration: InputDecoration(
                  labelText: p == null ? 'PDF password' : 'New password (optional)',
                  suffixIcon: IconButton(
                    icon: Icon(hide ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setS(() => hide = !hide),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final name = label.text.trim();
    if (name.isEmpty || (p == null && pw.text.isEmpty)) {
      messenger.showSnackBar(const SnackBar(content: Text('Enter a name and a password')));
      return;
    }
    try {
      if (p == null) {
        await api.post('/pdf-passwords', body: {'label': name, 'password': pw.text});
      } else {
        await api.patch('/pdf-passwords/${p.id}', body: {
          'label': name,
          if (pw.text.isNotEmpty) 'password': pw.text,
        });
      }
      ref.invalidate(pdfPasswordsProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_err(e))));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, SavedPassword p) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showAppSheet<bool>(
      context: context,
      builder: (d) => SheetFrame(
        title: const Text('Delete password?'),
        content: Text('"${p.label}" will be removed. You can add it again later.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Delete', style: TextStyle(color: AppColors.red100))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.delete('/pdf-passwords/${p.id}');
      ref.invalidate(pdfPasswordsProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_err(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(pdfPasswordsProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.dark100,
        centerTitle: true,
        title: const Text('PDF passwords', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/')),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.violet100,
        onPressed: () => _form(context, ref),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: list.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Could not load passwords\n${_err(e)}', textAlign: TextAlign.center),
              TextButton(
                  onPressed: () => ref.invalidate(pdfPasswordsProvider),
                  child: const Text('Retry')),
            ],
          ),
        ),
        data: (items) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            Text(
              'Saved encrypted on your account. When a bank PDF is locked, these are tried automatically.',
              style: TextStyle(color: Colors.grey[600], height: 1.4),
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                    child: Text('No saved passwords',
                        style: TextStyle(color: Colors.grey[600]))),
              ),
            for (final p in items)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: const Icon(Icons.key, color: AppColors.violet100),
                  title: Text(p.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(p.lastUsedAt == null
                      ? 'Not used yet'
                      : 'Last used ${shortDate(p.lastUsedAt!)} ${p.lastUsedAt!.year}'),
                  onTap: () => _form(context, ref, p),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.red100),
                    onPressed: () => _delete(context, ref, p),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
