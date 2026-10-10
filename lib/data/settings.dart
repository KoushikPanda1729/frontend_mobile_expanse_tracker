import 'dart:io';

import 'package:expensetracker/data/api.dart';
import 'package:expensetracker/data/auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

class Profile {
  final String name;
  final String handle;
  final String? photoPath;
  const Profile(this.name, this.handle, {this.photoPath});
}

/// The signed-in user's profile, loaded from GET /users/me.
final profileProvider =
    NotifierProvider<ProfileNotifier, Profile>(ProfileNotifier.new);

class ProfileNotifier extends Notifier<Profile> {
  @override
  Profile build() {
    if (ref.watch(authProvider).valueOrNull == true) _load();
    return const Profile('', '');
  }

  static Profile _from(Map<String, dynamic> u, String? photo) {
    final name = u['name'] as String;
    final handle = (u['username'] as String?) ?? name.split(' ').first.toLowerCase();
    return Profile(name, handle, photoPath: photo);
  }

  Future<void> _load() async {
    try {
      final u = await api.get('/users/me') as Map<String, dynamic>;
      state = _from(u, null);
      if (u['photoUrl'] != null) {
        final photo = await _downloadPhoto();
        if (photo != null) state = _from(u, photo);
      }
    } catch (_) {} // offline: the app still works, the name stays empty
  }

  Future<String?> _downloadPhoto() async {
    try {
      final b = await api.bytes('/users/me/photo');
      final dir = await getTemporaryDirectory();
      // a new file name each time so the image cache never shows the old photo
      final f = File('${dir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await f.writeAsBytes(b);
      return f.path;
    } catch (_) {
      return null;
    }
  }

  /// [photoPath] null = no photo. A path different from the current one is uploaded.
  /// Throws [ApiException] when the server refuses.
  Future<void> save({required String name, required String handle, String? photoPath}) async {
    final cur = state;
    final patch = <String, String>{'name': name};
    if (handle.isNotEmpty) patch['username'] = handle;
    await api.patch('/users/me', body: patch);
    if (photoPath != cur.photoPath) {
      if (photoPath == null) {
        await api.delete('/users/me/photo');
      } else {
        await api.upload('PUT', '/users/me/photo',
            field: 'photo', bytes: await File(photoPath).readAsBytes(), filename: 'photo.jpg');
      }
    }
    await _load();
  }
}

/// Deletes what the app left on this phone: downloaded statement PDFs and profile photo copies.
Future<void> clearLocalFiles() async {
  try {
    final dir = await getTemporaryDirectory();
    await for (final f in dir.list()) {
      final name = f.path.split(Platform.pathSeparator).last;
      if (f is File && (name.endsWith('.pdf') || name.startsWith('avatar_'))) {
        await f.delete();
      }
    }
  } catch (_) {} // best effort
}

/// Masks the balance on Home.
final hideBalanceProvider = StateProvider<bool>((ref) => false);
