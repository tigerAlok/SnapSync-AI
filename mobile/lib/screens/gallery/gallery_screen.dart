import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/room/room_model.dart';
import '../../providers/photo/photo_provider.dart';
import '../../providers/room/room_provider.dart';
import '../rooms/photo_viewer_screen.dart';
import '../../widgets/photo_details_sheet.dart';

class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsState = ref.watch(userRoomsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gallery'),
      ),
      body: roomsState.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to load gallery.\n$error',
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
        data: (rooms) {
          if (rooms.isEmpty) {
            return const _EmptyGalleryView();
          }

          return ListView.builder(
            padding: const EdgeInsets.only(
              bottom: 32,
            ),
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              return _RoomGallerySection(
                room: rooms[index],
              );
            },
          );
        },
      ),
    );
  }
}

class _RoomGallerySection extends ConsumerWidget {
  final RoomModel room;

  const _RoomGallerySection({
    required this.room,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photosState = ref.watch(
      roomPhotosProvider(room.id),
    );

    return photosState.when(
      loading: () {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
      error: (error, stackTrace) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Could not load photos from ${room.name}',
          ),
        );
      },
      data: (photos) {
        if (photos.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            16,
            20,
            16,
            8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      room.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Text(
                    '${photos.length} photo(s)',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics:
                    const NeverScrollableScrollPhysics(),
                itemCount: photos.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  final photo = photos[index];

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PhotoViewerScreen(
                            photos: photos,
                            initialIndex: index,
                          ),
                        ),
                      );
                    },
                    onLongPress: () {
                        PhotoDetailsSheet.show(
                          context,
                          photo: photo,
                          roomName: room.name,
                        );
                      },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        photo.imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (
                          context,
                          child,
                          loadingProgress,
                        ) {
                          if (loadingProgress == null) {
                            return child;
                          }

                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        },
                        errorBuilder: (
                          context,
                          error,
                          stackTrace,
                        ) {
                          return const Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyGalleryView extends StatelessWidget {
  const _EmptyGalleryView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 80,
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.6),
            ),
            const SizedBox(height: 20),
            Text(
              'Your gallery is empty',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Join or create a room and share photos to see them here.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}