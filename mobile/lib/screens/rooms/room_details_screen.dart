import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/photo/photo_model.dart';
import '../../models/room/room_model.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/photo/photo_provider.dart';
import '../../providers/room/room_provider.dart';
import '../../services/download/photo_download_service.dart';
import 'photo_viewer_screen.dart';

class RoomDetailsScreen extends ConsumerStatefulWidget {
  final RoomModel room;

  const RoomDetailsScreen({
    super.key,
    required this.room,
  });

  @override
  ConsumerState<RoomDetailsScreen> createState() =>
      _RoomDetailsScreenState();
}

class _RoomDetailsScreenState
    extends ConsumerState<RoomDetailsScreen> {
  final Set<String> _selectedPhotoIds = {};

  final PhotoDownloadService _downloadService =
      PhotoDownloadService();

  bool _isSelectionMode = false;
  bool _isDownloadingSelected = false;

  RoomModel get room => widget.room;

  // --------------------------------------------------
  // PICK AND UPLOAD PHOTOS
  // --------------------------------------------------

  Future<void> _pickAndUploadPhotos() async {
    final user = ref.read(authStateProvider).valueOrNull;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You must be signed in to upload photos.',
          ),
        ),
      );

      return;
    }

    final picker = ImagePicker();

    final List<XFile> images = await picker.pickMultiImage(
      imageQuality: 85,
    );

    if (images.isEmpty) {
      return;
    }

    final success = await ref
        .read(photoUploadControllerProvider.notifier)
        .uploadPhotos(
          images: images,
          roomId: room.id,
          uploaderId: user.id,
          uploaderName: user.displayName,
        );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${images.length} photo(s) uploaded successfully.',
          ),
        ),
      );
    }
  }

  // --------------------------------------------------
  // LEAVE ROOM
  // --------------------------------------------------

  Future<void> _leaveRoom(
    RoomModel currentRoom,
  ) async {
    final user = ref.read(authStateProvider).valueOrNull;

    if (user == null) {
      return;
    }

    if (currentRoom.ownerId == user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The room owner cannot leave the room.',
          ),
        ),
      );

      return;
    }

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Leave Room?'),
          content: Text(
            'Are you sure you want to leave '
            '"${currentRoom.name}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );

    if (shouldLeave != true || !mounted) {
      return;
    }

    final success = await ref
        .read(roomControllerProvider.notifier)
        .leaveRoom(
          roomId: currentRoom.id,
          userId: user.id,
        );

    if (!mounted) {
      return;
    }

    if (success) {
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You left the room.',
          ),
        ),
      );
    }
  }

  // --------------------------------------------------
  // DELETE ROOM
  // --------------------------------------------------

  Future<void> _deleteRoom(
    RoomModel currentRoom,
  ) async {
    final user = ref.read(authStateProvider).valueOrNull;

    if (user == null) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (currentRoom.ownerId != user.id) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Only the room owner can delete this room.',
          ),
        ),
      );

      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Room?'),
          content: Text(
            'Delete "${currentRoom.name}" and its photo metadata? '
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    final success = await ref
        .read(roomControllerProvider.notifier)
        .deleteRoom(
          roomId: currentRoom.id,
          userId: user.id,
        );

    if (success) {
      navigator.pop();

      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Room deleted successfully.',
          ),
        ),
      );
    }
  }

  // --------------------------------------------------
  // SELECTION METHODS
  // --------------------------------------------------

  void _startSelection(String photoId) {
    setState(() {
      _isSelectionMode = true;
      _selectedPhotoIds.add(photoId);
    });
  }

  void _toggleSelection(String photoId) {
    setState(() {
      if (_selectedPhotoIds.contains(photoId)) {
        _selectedPhotoIds.remove(photoId);
      } else {
        _selectedPhotoIds.add(photoId);
      }

      if (_selectedPhotoIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectedPhotoIds.clear();
      _isSelectionMode = false;
    });
  }

  // --------------------------------------------------
  // DOWNLOAD SELECTED PHOTOS
  // --------------------------------------------------

  Future<void> _downloadSelectedPhotos(
    List<PhotoModel> photos,
  ) async {
    if (_selectedPhotoIds.isEmpty ||
        _isDownloadingSelected) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isDownloadingSelected = true;
    });

    int downloadedCount = 0;

    try {
      final selectedPhotos = photos.where(
        (photo) =>
            _selectedPhotoIds.contains(photo.id),
      );

      for (final photo in selectedPhotos) {
        await _downloadService.savePhotoToGallery(
          photo.imageUrl,
        );

        downloadedCount++;
      }

      if (!mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '$downloadedCount photo(s) saved to gallery.',
          ),
        ),
      );

      _cancelSelection();
    } catch (error) {
      if (!mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Download failed after '
            '$downloadedCount photo(s): $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingSelected = false;
        });
      }
    }
  }

  // --------------------------------------------------
  // NORMAL APP BAR
  // --------------------------------------------------

  AppBar _buildNormalAppBar(
    RoomModel liveRoom,
  ) {
    return AppBar(
      title: Text(liveRoom.name),
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'leave') {
              _leaveRoom(liveRoom);
            } else if (value == 'delete') {
              _deleteRoom(liveRoom);
            }
          },
          itemBuilder: (context) {
            final user =
                ref.read(authStateProvider).valueOrNull;

            final isOwner =
                user?.id == liveRoom.ownerId;

            if (isOwner) {
              return const [
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                      ),
                      SizedBox(width: 12),
                      Text('Delete Room'),
                    ],
                  ),
                ),
              ];
            }

            return const [
              PopupMenuItem(
                value: 'leave',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 12),
                    Text('Leave Room'),
                  ],
                ),
              ),
            ];
          },
        ),
      ],
    );
  }

  // --------------------------------------------------
  // SELECTION APP BAR
  // --------------------------------------------------

  AppBar _buildSelectionAppBar(
    List<PhotoModel> photos,
  ) {
    return AppBar(
      leading: IconButton(
        tooltip: 'Cancel selection',
        icon: const Icon(Icons.close),
        onPressed: _cancelSelection,
      ),
      title: Text(
        '${_selectedPhotoIds.length} selected',
      ),
      actions: [
        IconButton(
          tooltip: 'Download selected photos',
          onPressed: _isDownloadingSelected
              ? null
              : () {
                  _downloadSelectedPhotos(photos);
                },
          icon: _isDownloadingSelected
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(
                  Icons.download_outlined,
                ),
        ),
      ],
    );
  }

  // --------------------------------------------------
  // BUILD
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final liveRoomState = ref.watch(
      roomDetailsProvider(room.id),
    );

    final liveRoom =
        liveRoomState.valueOrNull ?? room;

    final photosState = ref.watch(
      roomPhotosProvider(room.id),
    );

    final uploadState = ref.watch(
      photoUploadControllerProvider,
    );

    final isUploading = uploadState.isLoading;

    final currentPhotos =
        photosState.valueOrNull ?? <PhotoModel>[];

    ref.listen(
      photoUploadControllerProvider,
      (previous, next) {
        if (next.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                next.error.toString(),
              ),
            ),
          );
        }
      },
    );

    return Scaffold(
      appBar: _isSelectionMode
          ? _buildSelectionAppBar(currentPhotos)
          : _buildNormalAppBar(liveRoom),

      body: Column(
        children: [
          if (isUploading)
            const LinearProgressIndicator(),

          Expanded(
            child: CustomScrollView(
              slivers: [
                // --------------------------------------------------
                // ROOM INFORMATION CARD
                // --------------------------------------------------

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Card(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              liveRoom.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                            ),

                            const SizedBox(height: 20),

                            Row(
                              children: [
                                const Icon(
                                  Icons.key_outlined,
                                ),

                                const SizedBox(width: 12),

                                const Text(
                                  'Room Code',
                                ),

                                const Spacer(),

                                Text(
                                  liveRoom.code,
                                  style:
                                      const TextStyle(
                                    fontSize: 18,
                                    fontWeight:
                                        FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),

                                IconButton(
                                  tooltip:
                                      'Copy room code',
                                  icon: const Icon(
                                    Icons.copy_outlined,
                                  ),
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(
                                        text:
                                            liveRoom.code,
                                      ),
                                    );

                                    ScaffoldMessenger.of(
                                      context,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Room code copied',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            Row(
                              children: [
                                const Icon(
                                  Icons.people_outline,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${liveRoom.memberIds.length} '
                                  'member(s)',
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            SizedBox(
                              width: double.infinity,
                              child:
                                  OutlinedButton.icon(
                                onPressed: () {
                                  SharePlus.instance.share(
                                    ShareParams(
                                      text:
                                          'Join my SnapSync AI room '
                                          '"${liveRoom.name}"!\n\n'
                                          'Room Code: '
                                          '${liveRoom.code}',
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.share_outlined,
                                ),
                                label: const Text(
                                  'Share Room Invitation',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // --------------------------------------------------
                // SHARED PHOTOS TITLE
                // --------------------------------------------------

                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(
                      20,
                      8,
                      20,
                      16,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Shared Photos',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                          ),
                        ),

                        if (!_isSelectionMode &&
                            currentPhotos.isNotEmpty)
                          Text(
                            'Long press to select',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall,
                          ),
                      ],
                    ),
                  ),
                ),

                // --------------------------------------------------
                // PHOTO GRID
                // --------------------------------------------------

                photosState.when(
                  loading: () =>
                      const SliverFillRemaining(
                    child: Center(
                      child:
                          CircularProgressIndicator(),
                    ),
                  ),

                  error: (error, stackTrace) =>
                      SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(24),
                        child: Text(
                          'Unable to load photos.\n'
                          '$error',
                          textAlign:
                              TextAlign.center,
                        ),
                      ),
                    ),
                  ),

                  data: (photos) {
                    if (photos.isEmpty) {
                      return const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyPhotosView(),
                      );
                    }

                    return SliverPadding(
                      padding:
                          const EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        100,
                      ),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        delegate:
                            SliverChildBuilderDelegate(
                          (context, index) {
                            final photo =
                                photos[index];

                            final isSelected =
                                _selectedPhotoIds
                                    .contains(
                              photo.id,
                            );

                            return GestureDetector(
                              // ------------------------------------
                              // TAP
                              // ------------------------------------

                              onTap: () {
                                if (_isSelectionMode) {
                                  _toggleSelection(
                                    photo.id,
                                  );

                                  return;
                                }

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (
                                      context,
                                    ) =>
                                        PhotoViewerScreen(
                                      photos: photos,
                                      initialIndex:
                                          index,
                                    ),
                                  ),
                                );
                              },

                              // ------------------------------------
                              // LONG PRESS
                              // ------------------------------------

                              onLongPress: () {
                                if (!_isSelectionMode) {
                                  _startSelection(
                                    photo.id,
                                  );
                                }
                              },

                              // ------------------------------------
                              // PHOTO + SELECTION OVERLAY
                              // ------------------------------------

                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Hero(
                                    tag: photo.id,
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        12,
                                      ),
                                      child:
                                          Image.network(
                                        photo.imageUrl,
                                        fit:
                                            BoxFit.cover,
                                        loadingBuilder: (
                                          context,
                                          child,
                                          loadingProgress,
                                        ) {
                                          if (loadingProgress ==
                                              null) {
                                            return child;
                                          }

                                          return const Center(
                                            child:
                                                CircularProgressIndicator(),
                                          );
                                        },
                                        errorBuilder: (
                                          context,
                                          error,
                                          stackTrace,
                                        ) {
                                          return const Center(
                                            child: Icon(
                                              Icons
                                                  .broken_image_outlined,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),

                                  if (isSelected)
                                    Container(
                                      decoration:
                                          BoxDecoration(
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                          12,
                                        ),
                                        color:
                                            Colors.black38,
                                      ),
                                      child:
                                          const Center(
                                        child: Icon(
                                          Icons
                                              .check_circle,
                                          size: 40,
                                          color:
                                              Colors.white,
                                        ),
                                      ),
                                    ),

                                  if (_isSelectionMode &&
                                      !isSelected)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        width: 24,
                                        height: 24,
                                        decoration:
                                            BoxDecoration(
                                          shape:
                                              BoxShape.circle,
                                          border:
                                              Border.all(
                                            color:
                                                Colors.white,
                                            width: 2,
                                          ),
                                          color:
                                              Colors.black26,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                          childCount: photos.length,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),

      // --------------------------------------------------
      // ADD PHOTOS BUTTON
      // --------------------------------------------------

      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed:
                  isUploading ? null : _pickAndUploadPhotos,
              icon: isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons
                          .add_photo_alternate_outlined,
                    ),
              label: Text(
                isUploading
                    ? 'Uploading...'
                    : 'Add Photos',
              ),
            ),
    );
  }
}

// --------------------------------------------------
// EMPTY PHOTO VIEW
// --------------------------------------------------

class _EmptyPhotosView extends StatelessWidget {
  const _EmptyPhotosView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 70,
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(
                    alpha: 0.6,
                  ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No photos shared yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap Add Photos to share memories '
              'with this room.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}