import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),

      error: (error, stackTrace) => Center(
        child: Text(
          'Failed to load profile\n$error',
          textAlign: TextAlign.center,
        ),
      ),

      data: (user) {
        if (user == null) {
          return const Center(
            child: Text('No user is currently signed in.'),
          );
        }

        final displayName = user.displayName?.trim();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),

              CircleAvatar(
                radius: 55,
                backgroundImage:
                    user.photoUrl != null && user.photoUrl!.isNotEmpty
                        ? NetworkImage(user.photoUrl!)
                        : null,
                child: user.photoUrl == null || user.photoUrl!.isEmpty
                    ? const Icon(
                        Icons.person,
                        size: 55,
                      )
                    : null,
              ),

              const SizedBox(height: 20),

              Text(
                displayName != null && displayName.isNotEmpty
                    ? displayName
                    : 'SnapSync User',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),

              const SizedBox(height: 8),

              Text(
                user.email,
                style: Theme.of(context).textTheme.bodyLarge,
              ),

              const SizedBox(height: 40),

              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: const Text('Edit Profile'),
                      trailing:
                          const Icon(Icons.chevron_right),
                      onTap: () {
                        // We will build this later.
                      },
                    ),

                    const Divider(height: 1),

                    ListTile(
                      leading:
                          const Icon(Icons.settings_outlined),
                      title: const Text('Settings'),
                      trailing:
                          const Icon(Icons.chevron_right),
                      onTap: () {
                        // We will build this later.
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                  onPressed: () async {
                    await ref
                        .read(authControllerProvider.notifier)
                        .signOut();

                    if (context.mounted) {
                      context.go('/login');
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}