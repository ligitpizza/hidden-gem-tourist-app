import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/theme_mode_controller.dart';
import '../../auth/model/auth_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    final fullName = user?.userMetadata?['full_name'] as String? ?? 'Traveller';
    final colorScheme = Theme.of(context).colorScheme;
    final themeModeController = ref.watch(themeModeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(Icons.person, size: 36, color: colorScheme.onPrimaryContainer),
          ),
          const SizedBox(height: 16),
          Text(
            fullName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          if (user?.email != null)
            Text(
              user!.email!,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => AuthRepository().signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Log Out'),
          ),
          const SizedBox(height: 32),
          Text(
            'APPEARANCE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
              ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('System')),
            ],
            selected: {themeModeController.themeMode},
            onSelectionChanged: (selection) =>
                ref.read(themeModeControllerProvider).setThemeMode(selection.first),
          ),
        ],
      ),
    );
  }
}
