import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/photo/photo_model.dart';
import '../../providers/photo/photo_provider.dart';
import '../../providers/room/room_provider.dart';
import '../../services/api/api_service.dart';
import '../rooms/photo_viewer_screen.dart';




class SimilarPhotoResult {
  final PhotoModel photo;
  final double similarity;

  const SimilarPhotoResult({
    required this.photo,
    required this.similarity,
  });
}

enum SimilarSearchMode {
  similar,
  duplicates,
}


class SimilarPhotosScreen
    extends ConsumerStatefulWidget {
  const SimilarPhotosScreen({
    super.key,
  });

  @override
  ConsumerState<SimilarPhotosScreen>
      createState() =>
          _SimilarPhotosScreenState();
}






class _SimilarPhotosScreenState
    extends ConsumerState<SimilarPhotosScreen> {
  final ApiService _apiService =
      ApiService();


  SimilarSearchMode _searchMode =
    SimilarSearchMode.similar;    


      

  List<PhotoModel> _allPhotos = [];
  List<SimilarPhotoResult> _similarPhotos = [];

  PhotoModel? _referencePhoto;

  bool _isLoadingPhotos = true;
  bool _isSearching = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      _loadAllPhotos();
    });
  }

  Future<void> _loadAllPhotos() async {
    final roomsState = ref.read(
      userRoomsProvider,
    );

    final rooms =
        roomsState.valueOrNull ?? [];

    if (rooms.isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingPhotos = false;
        _errorMessage =
            'Join or create a room first.';
      });

      return;
    }

    try {
      final List<PhotoModel> photos = [];

      for (final room in rooms) {
        final roomPhotos = await ref
            .read(
              photoRepositoryProvider,
            )
            .getRoomPhotos(
              room.id,
            );

        photos.addAll(
          roomPhotos,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _allPhotos = photos;
        _isLoadingPhotos = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingPhotos = false;
        _errorMessage =
            'Unable to load photos: $error';
      });
    }
  }

  Future<void> _findSimilarPhotos(
    PhotoModel referencePhoto,
  ) async {
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
      return;
    }

    setState(() {
      _referencePhoto = referencePhoto;
      _similarPhotos = [];
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final Map<String, dynamic> result;

      if (_searchMode ==
          SimilarSearchMode.similar) {
        result =
            await _apiService.getSimilarPhotos(
          roomId: referencePhoto.roomId,
          photoId: referencePhoto.id,
          roomIds: roomIds,
        );
      } else {
        result =
            await _apiService.getDuplicatePhotos(
          roomId: referencePhoto.roomId,
          photoId: referencePhoto.id,
          roomIds: roomIds,
        );
      }

      final rawMatches =
          result['matches']
                  as List<dynamic>? ??
              [];

      final List<SimilarPhotoResult>
          loadedPhotos = [];

      for (final rawMatch in rawMatches) {
        final match =
            rawMatch as Map<String, dynamic>;

        final roomId =
            match['roomId'] as String?;

        final photoId =
            match['photoId'] as String?;

        final similarity =
            (match['similarity'] as num?)
                    ?.toDouble() ??
                0.0;

        if (roomId == null ||
            photoId == null) {
          continue;
        }

        final photo = await ref
            .read(
              photoRepositoryProvider,
            )
            .getPhoto(
              roomId: roomId,
              photoId: photoId,
            );

        if (photo != null) {
          loadedPhotos.add(
            SimilarPhotoResult(
              photo: photo,
              similarity: similarity,
            ),
          );
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _similarPhotos = loadedPhotos;
        _isSearching = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSearching = false;
        _errorMessage =
            'Similar photo search failed: $error';
      });
    }
  }

  void _openPhoto(
    int index,
  ) {
    final photos = _similarPhotos
        .map(
          (result) => result.photo,
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

  void _chooseAnotherPhoto() {
    setState(() {
      _referencePhoto = null;
      _similarPhotos = [];
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Similar Photos',
        ),
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoadingPhotos) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_referencePhoto == null) {
      return _buildReferencePicker();
    }

    return _buildResults();
  }

  Widget _buildReferencePicker() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_allPhotos.isEmpty) {
      return const Center(
        child: Text(
          'No photos available.',
        ),
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              SegmentedButton<
                  SimilarSearchMode>(
                segments: const [
                  ButtonSegment(
                    value:
                        SimilarSearchMode.similar,
                    label: Text(
                      'Similar',
                    ),
                    icon: Icon(
                      Icons.collections_outlined,
                    ),
                  ),
                  ButtonSegment(
                    value:
                        SimilarSearchMode.duplicates,
                    label: Text(
                      'Duplicates',
                    ),
                    icon: Icon(
                      Icons.copy_all_outlined,
                    ),
                  ),
                ],
                selected: {
                  _searchMode,
                },
                onSelectionChanged: (
                  selection,
                ) {
                  setState(() {
                    _searchMode =
                        selection.first;
                  });
                },
              ),

              const SizedBox(height: 16),

              Text(
                _searchMode ==
                        SimilarSearchMode.similar
                    ? 'Choose a photo to find '
                        'visually similar images.'
                    : 'Choose a photo to find '
                        'near-duplicate images.',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium,
              ),
            ],
          ),
        ),

        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(4),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemCount: _allPhotos.length,
            itemBuilder: (
              context,
              index,
            ) {
              final photo =
                  _allPhotos[index];

              return InkWell(
                onTap: () {
                  _findSimilarPhotos(
                    photo,
                  );
                },
                child: Image.network(
                  photo.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (
                    context,
                    error,
                    stackTrace,
                  ) {
                    return const ColoredBox(
                      color: Colors.black12,
                      child: Center(
                        child: Icon(
                          Icons
                              .broken_image_outlined,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResults() {
    return Column(
      children: [
        Padding(
          padding:
              const EdgeInsets.all(16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(10),
                child: Image.network(
                  _referencePhoto!.imageUrl,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Text(
                  _searchMode ==
                          SimilarSearchMode.similar
                      ? 'Showing visually similar photos.'
                      : 'Showing near-duplicate photos.',
                ),
              ),

              TextButton(
                onPressed:
                    _chooseAnotherPhoto,
                child: const Text(
                  'Change',
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        Expanded(
          child: _buildResultGrid(),
        ),
      ],
    );
  }

  Widget _buildResultGrid() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_similarPhotos.isEmpty) {
      return Center(
        child: Text(
          _searchMode ==
                  SimilarSearchMode.similar
              ? 'No similar photos found.'
              : 'No near-duplicates found.',
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _similarPhotos.length,
      itemBuilder: (
        context,
        index,
      ) {
        final result =
            _similarPhotos[index];

        final photo =
            result.photo;

        final similarityPercent =
            (result.similarity * 100)
                .round();

        return GestureDetector(
          onTap: () {
            _openPhoto(index);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: photo.id,
                child: Image.network(
                  photo.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (
                    context,
                    error,
                    stackTrace,
                  ) {
                    return const ColoredBox(
                      color: Colors.black12,
                      child: Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                        ),
                      ),
                    );
                  },
                ),
              ),

              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius:
                        BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$similarityPercent% similar',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}