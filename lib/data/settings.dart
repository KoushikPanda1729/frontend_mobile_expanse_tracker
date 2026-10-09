import 'package:flutter_riverpod/flutter_riverpod.dart';

class Profile {
  final String name;
  final String handle;
  final String? photoPath;
  const Profile(this.name, this.handle, {this.photoPath});
}

final profileProvider =
    StateProvider<Profile>((ref) => const Profile('Koushik Panda', 'koushik'));

/// Masks the balance on Home.
final hideBalanceProvider = StateProvider<bool>((ref) => false);
