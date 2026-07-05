import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth/auth_provider.dart';
import '../../providers/room/room_provider.dart';
import 'room_details_screen.dart';

class RoomsScreen extends ConsumerWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsState = ref.watch(userRoomsProvider);
    final authState = ref.watch(authStateProvider);
    final controllerState = ref.watch(roomControllerProvider);

    final user = authState.valueOrNull;
    final isLoading = controllerState.isLoading;

    ref.listen(roomControllerProvider, (previous, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.error.toString(),
            ),
          ),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: user == null || isLoading
                          ? null
                          : () {
                              _showCreateRoomDialog(
                                context,
                                ref,
                                user.id,
                              );
                            },
                      icon: const Icon(Icons.add),
                      label: const Text('Create Room'),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: user == null || isLoading
                          ? null
                          : () {
                              _showJoinRoomDialog(
                                context,
                                ref,
                                user.id,
                              );
                            },
                      icon: const Icon(Icons.login),
                      label: const Text('Join Room'),
                    ),
                  ),
                ],
              ),
            ),

            if (isLoading)
              const LinearProgressIndicator(),

            Expanded(
              child: roomsState.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),

                error: (error, stackTrace) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Unable to load rooms.\n$error',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                data: (rooms) {
                  if (rooms.isEmpty) {
                    return const _EmptyRoomsView();
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: rooms.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final room = rooms[index];

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              room.name.isNotEmpty
                                  ? room.name[0].toUpperCase()
                                  : 'R',
                            ),
                          ),
                          title: Text(
                            room.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            '${room.memberIds.length} member(s) • Code: ${room.code}',
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RoomDetailsScreen(
                                  room: room,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateRoomDialog(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create Room'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Room Name',
              hintText: 'Example: Goa Trip 2026',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();

                if (name.isEmpty) {
                  return;
                }

                Navigator.pop(dialogContext);

                final room = await ref
                    .read(roomControllerProvider.notifier)
                    .createRoom(
                      name: name,
                      ownerId: userId,
                    );

                if (!context.mounted) return;

                if (room != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Room created. Code: ${room.code}',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    ).whenComplete(nameController.dispose);
  }

  void _showJoinRoomDialog(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Join Room'),
          content: TextField(
            controller: codeController,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Room Code',
              hintText: 'Example: A7K9P2',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final code = codeController.text.trim();

                if (code.isEmpty) {
                  return;
                }

                Navigator.pop(dialogContext);

                final room = await ref
                    .read(roomControllerProvider.notifier)
                    .joinRoom(
                      code: code,
                      userId: userId,
                    );

                if (!context.mounted) return;

                if (room != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Joined ${room.name}',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Join'),
            ),
          ],
        );
      },
    ).whenComplete(codeController.dispose);
  }
}

class _EmptyRoomsView extends StatelessWidget {
  const _EmptyRoomsView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.groups_outlined,
              size: 80,
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.6),
            ),
            const SizedBox(height: 20),
            Text(
              'No rooms yet',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a room for your event or join one using a room code.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}