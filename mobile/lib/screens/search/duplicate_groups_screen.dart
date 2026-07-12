import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/photo/photo_model.dart';
import '../../providers/photo/photo_provider.dart';
import '../../providers/room/room_provider.dart';
import '../../services/api/api_service.dart';
import '../rooms/photo_viewer_screen.dart';

class DuplicatePhotoItem {
  final PhotoModel photo;
  final int hashDistance;
  final double? qualityScore;
  final bool recommendedKeep;

  const DuplicatePhotoItem({
    required this.photo,
    required this.hashDistance,
    required this.qualityScore,
    required this.recommendedKeep,
  });
}

class DuplicateGroupsScreen
    extends ConsumerStatefulWidget {
  const DuplicateGroupsScreen({
    super.key,
  });

  @override
  ConsumerState<DuplicateGroupsScreen>
      createState() =>
          _DuplicateGroupsScreenState();
}

class _DuplicateGroupsScreenState
    extends ConsumerState<DuplicateGroupsScreen> {
  final ApiService _apiService = ApiService();

  List<List<DuplicatePhotoItem>> _groups = [];

  final Set<String> _selectedPhotoKeys = {};

  bool _isLoading = true;
  bool _isDeleting = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) async {
        await _prepareDuplicateGroups();
      },
    );
  }





  // --------------------------------------------------
  // PREPARE DUPLICATE GROUPS
  // --------------------------------------------------

  Future<void> _prepareDuplicateGroups() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _backfillMissingQuality();

      if (!mounted) {
        return;
      }

      await _loadDuplicateGroups();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Unable to prepare duplicate groups.\n\n'
            '$error';
      });
    }
  }


  // --------------------------------------------------
  // BACKFILL MISSING PHOTO QUALITY
  // --------------------------------------------------

  Future<void> _backfillMissingQuality() async {
    final roomsState = ref.read(
      userRoomsProvider,
    );

    final rooms =
        roomsState.valueOrNull ?? [];

    final repository = ref.read(
      photoRepositoryProvider,
    );

    for (final room in rooms) {
      try {
        final qualityIndexedIds =
            await _apiService
                .getQualityIndexedPhotoIds(
          roomId: room.id,
        );

        final indexedSet =
            qualityIndexedIds.toSet();

        final photos =
            await repository.getRoomPhotos(
          room.id,
        );

        final missingPhotos = photos.where(
          (photo) {
            return !indexedSet.contains(
              photo.id,
            );
          },
        ).toList();

        for (final photo in missingPhotos) {
          try {
            await _apiService.processPhotoQuality(
              roomId: photo.roomId,
              photoId: photo.id,
              imageUrl: photo.imageUrl,
            );
          } catch (error) {
            debugPrint(
              'Quality processing failed for '
              '${photo.id}: $error',
            );
          }
        }
      } catch (error) {
        debugPrint(
          'Quality backfill failed for room '
          '${room.id}: $error',
        );
      }
    }
  }

  // --------------------------------------------------
  // LOAD DUPLICATE GROUPS
  // --------------------------------------------------

  Future<void> _loadDuplicateGroups() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final roomsState = ref.read(
        userRoomsProvider,
      );

      final rooms =
          roomsState.valueOrNull ?? [];

      final roomIds = rooms
          .map(
            (room) => room.id,
          )
          .toList();

      if (roomIds.isEmpty) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isLoading = false;
          _errorMessage =
              'Join or create a room first.';
        });

        return;
      }

      final response =
          await _apiService.getDuplicateGroups(
        roomIds: roomIds,
      );

      final rawGroups =
          response['groups']
                  as List<dynamic>? ??
              [];

      final repository = ref.read(
        photoRepositoryProvider,
      );

      final groupFutures =
          rawGroups.map((rawGroup) async {
        final group =
            rawGroup as List<dynamic>;

        final itemFutures =
            group.map((rawItem) async {
          final item =
              rawItem as Map<String, dynamic>;

          final roomId =
              item['roomId'] as String?;

          final photoId =
              item['photoId'] as String?;

          final hashDistance =
              (item['hashDistance'] as num?)
                      ?.toInt() ??
                  0;


          final qualityScore =
              (item['qualityScore'] as num?)
                  ?.toDouble();

          final recommendedKeep =
              item['recommendedKeep'] as bool? ??
                  false;        

          if (roomId == null ||
              photoId == null) {
            return null;
          }

          final photo =
              await repository.getPhoto(
            roomId: roomId,
            photoId: photoId,
          );

          if (photo == null) {
            return null;
          }
          return DuplicatePhotoItem(
            photo: photo,
            hashDistance: hashDistance,
            qualityScore: qualityScore,
            recommendedKeep: recommendedKeep,
          );
        }).toList();

        final loadedItems =
            await Future.wait(
          itemFutures,
        );

        return loadedItems
            .whereType<DuplicatePhotoItem>()
            .toList();
      }).toList();

      final loadedGroups =
          await Future.wait(
        groupFutures,
      );

      final validGroups = loadedGroups
          .where(
            (group) => group.length > 1,
          )
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _groups = validGroups;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;

        _errorMessage =
            'Unable to load duplicate groups.\n\n'
            '$error';
      });
    }
  }

  // --------------------------------------------------
  // OPEN PHOTO VIEWER
  // --------------------------------------------------

  void _openPhoto(
    List<DuplicatePhotoItem> group,
    int index,
  ) {
    final photos = group
        .map(
          (item) => item.photo,
        )
        .toList();

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
  }

  // --------------------------------------------------
  // PHOTO KEY
  // --------------------------------------------------

  String _photoKey(
    PhotoModel photo,
  ) {
    return '${photo.roomId}:${photo.id}';
  }

  // --------------------------------------------------
  // CHECK SELECTION
  // --------------------------------------------------

  bool _isSelected(
    PhotoModel photo,
  ) {
    return _selectedPhotoKeys.contains(
      _photoKey(photo),
    );
  }

  // --------------------------------------------------
  // TOGGLE SELECTION
  // --------------------------------------------------

  void _toggleSelection(
    PhotoModel photo,
  ) {
    final key = _photoKey(photo);

    setState(() {
      if (_selectedPhotoKeys.contains(key)) {
        _selectedPhotoKeys.remove(key);
      } else {
        _selectedPhotoKeys.add(key);
      }
    });
  }

  // --------------------------------------------------
  // CLEAR SELECTION
  // --------------------------------------------------

  void _clearSelection() {
    setState(() {
      _selectedPhotoKeys.clear();
    });
  }

  // --------------------------------------------------
  // CONFIRM DELETE
  // --------------------------------------------------

  Future<void> _confirmDeleteSelected() async {
    if (_selectedPhotoKeys.isEmpty ||
        _isDeleting) {
      return;
    }

    final selectedCount =
        _selectedPhotoKeys.length;

    final shouldDelete =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete selected photos?',
          ),
          content: Text(
            'Delete $selectedCount selected '
            'photo(s)?\n\n'
            'They will be removed from the room '
            'and from AI search indexes.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              icon: const Icon(
                Icons.delete_outline,
              ),
              label: const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    await _deleteSelectedPhotos();
  }

  // --------------------------------------------------
  // DELETE SELECTED PHOTOS
  // --------------------------------------------------

  Future<void> _deleteSelectedPhotos() async {
    if (_isDeleting) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    final repository = ref.read(
      photoRepositoryProvider,
    );

    final selectedPhotos = _groups
        .expand(
          (group) => group,
        )
        .where(
          (item) =>
              _selectedPhotoKeys.contains(
            _photoKey(
              item.photo,
            ),
          ),
        )
        .map(
          (item) => item.photo,
        )
        .toList();

    int deletedCount = 0;

    final failedPhotoIds = <String>[];

    for (final photo in selectedPhotos) {
      try {
        // Remove Firestore metadata.
        await _apiService.deletePhotoIndex(
          roomId: photo.roomId,
          photoId: photo.id,
          publicId: photo.publicId,
        );

        await repository.deletePhotoMetadata(
          roomId: photo.roomId,
          photoId: photo.id,
        );
        deletedCount++;
      } catch (error) {
        failedPhotoIds.add(
          photo.id,
        );

        debugPrint(
          'Failed to delete photo '
          '${photo.id}: $error',
        );
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isDeleting = false;
      _selectedPhotoKeys.clear();
    });

    await _loadDuplicateGroups();

    if (!mounted) {
      return;
    }

    if (failedPhotoIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$deletedCount photo(s) deleted.',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$deletedCount deleted, '
            '${failedPhotoIds.length} failed.',
          ),
        ),
      );
    }
  }

  // --------------------------------------------------
  // BUILD
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Duplicate Groups',
        ),
      ),

      body: _buildContent(),

      bottomNavigationBar:
          _selectedPhotoKeys.isEmpty
              ? null
              : SafeArea(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_selectedPhotoKeys.length} '
                            'selected',
                          ),
                        ),

                        TextButton(
                          onPressed: _isDeleting
                              ? null
                              : _clearSelection,
                          child: const Text(
                            'Clear',
                          ),
                        ),

                        const SizedBox(
                          width: 8,
                        ),

                        FilledButton.icon(
                          onPressed: _isDeleting
                              ? null
                              : _confirmDeleteSelected,
                          icon: _isDeleting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.delete_outline,
                                ),
                          label: Text(
                            _isDeleting
                                ? 'Deleting...'
                                : 'Delete',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  // --------------------------------------------------
  // MAIN CONTENT
  // --------------------------------------------------

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            CircularProgressIndicator(),

            SizedBox(
              height: 16,
            ),

            Text(
              'Finding duplicate groups...',
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                textAlign:
                    TextAlign.center,
              ),

              const SizedBox(
                height: 16,
              ),

              FilledButton(
                onPressed:
                    _loadDuplicateGroups,
                child: const Text(
                  'Try Again',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_groups.isEmpty) {
      return RefreshIndicator(
        onRefresh:
            _loadDuplicateGroups,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(
              height: 180,
            ),

            Icon(
              Icons.copy_all_outlined,
              size: 64,
            ),

            SizedBox(
              height: 16,
            ),

            Center(
              child: Text(
                'No duplicate groups found.',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh:
          _loadDuplicateGroups,
      child: ListView.separated(
        padding:
            const EdgeInsets.all(16),
        itemCount:
            _groups.length,
        separatorBuilder: (
          context,
          index,
        ) {
          return const SizedBox(
            height: 24,
          );
        },
        itemBuilder: (
          context,
          groupIndex,
        ) {
          final group =
              _groups[groupIndex];

          return _buildGroup(
            groupIndex,
            group,
          );
        },
      ),
    );
  }

  // --------------------------------------------------
  // DUPLICATE GROUP
  // --------------------------------------------------

  Widget _buildGroup(
    int groupIndex,
    List<DuplicatePhotoItem> group,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Group ${groupIndex + 1}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight:
                              FontWeight.bold,
                        ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    '${group.length} copies',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall,
                  ),
                ],
              ),
            ),

            TextButton.icon(
                onPressed: _isDeleting
                    ? null
                    : () {
                        setState(() {
                          for (final item in group) {
                            final key = _photoKey(
                              item.photo,
                            );

                            if (item.recommendedKeep) {
                              _selectedPhotoKeys.remove(
                                key,
                              );
                            } else {
                              _selectedPhotoKeys.add(
                                key,
                              );
                            }
                          }
                        });
                      },
              icon: const Icon(
                Icons.done_all,
                size: 18,
              ),
              label: const Text(
                'Select duplicates',
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 12,
        ),

        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection:
                Axis.horizontal,
            itemCount:
                group.length,
            separatorBuilder: (
              context,
              index,
            ) {
              return const SizedBox(
                width: 10,
              );
            },
            itemBuilder: (
              context,
              index,
            ) {
              final item =
                  group[index];

              final selected =
                  _isSelected(
                item.photo,
              );

              return GestureDetector(
                onTap: () {
                  if (_selectedPhotoKeys
                      .isNotEmpty) {
                    _toggleSelection(
                      item.photo,
                    );
                  } else {
                    _openPhoto(
                      group,
                      index,
                    );
                  }
                },

                onLongPress: () {
                  if (!_isDeleting) {
                    _toggleSelection(
                      item.photo,
                    );
                  }
                },

                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                  child: SizedBox(
                    width: 150,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          item.photo.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (
                            context,
                            error,
                            stackTrace,
                          ) {
                            return const ColoredBox(
                              color:
                                  Colors.black12,
                              child: Center(
                                child: Icon(
                                  Icons
                                      .broken_image_outlined,
                                ),
                              ),
                            );
                          },
                        ),



                        if (item.recommendedKeep)
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius:
                                    BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize:
                                    MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Best Copy',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight:
                                          FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        if (selected)
                          Container(
                            color: Colors.black26,
                          ),

                        if (selected)
                          const Positioned(
                            top: 6,
                            right: 6,
                            child: DecoratedBox(
                              decoration:
                                  BoxDecoration(
                                shape:
                                    BoxShape.circle,
                                color:
                                    Colors.white,
                              ),
                              child: Icon(
                                Icons.check_circle,
                                size: 28,
                              ),
                            ),
                          ),

                        Positioned(
                          left: 6,
                          bottom: 6,
                          child: Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  Colors.black87,
                              borderRadius:
                                  BorderRadius
                                      .circular(8),
                            ),
                            child: Text(
                              item.hashDistance == 0
                                  ? 'Reference'
                                  : 'Distance '
                                      '${item.hashDistance}',
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white,
                                fontSize: 11,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}