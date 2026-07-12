import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/photo/photo_model.dart';
import '../../../providers/photo/photo_provider.dart';
import '../../../providers/room/room_provider.dart';
import '../../../services/api/api_service.dart';
import '../../rooms/photo_viewer_screen.dart';

class CategoryPhotosScreen
    extends ConsumerStatefulWidget {
  final String categoryName;
  final String categoryValue;

  const CategoryPhotosScreen({
    super.key,
    required this.categoryName,
    required this.categoryValue,
  });

  @override
  ConsumerState<CategoryPhotosScreen>
      createState() =>
          _CategoryPhotosScreenState();
}

class _CategoryPhotosScreenState
    extends ConsumerState<CategoryPhotosScreen> {
  final ApiService _apiService =
      ApiService();

  List<PhotoModel> _photos = [];

  bool _isLoading = true;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      _loadPhotos();
    });
  }

  Future<void> _loadPhotos() async {
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
        _photos = [];
        _errorMessage =
            'Join or create a room first.';
      });

      return;
    }

    try {
      final result =
          await _apiService.getCategoryPhotos(
        category: widget.categoryValue,
        roomIds: roomIds,
      );

      final rawMatches =
          result['matches']
                  as List<dynamic>? ??
              [];

      final List<PhotoModel>
          loadedPhotos = [];

      for (final rawMatch in rawMatches) {
        final match =
            rawMatch as Map<String, dynamic>;

        final roomId =
            match['roomId'] as String?;

        final photoId =
            match['photoId'] as String?;

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
            photo,
          );
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _photos = loadedPhotos;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _photos = [];
        _isLoading = false;
        _errorMessage =
            'Unable to load photos: $error';
      });
    }
  }

  void _openPhoto(
    int index,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PhotoViewerScreen(
          photos: _photos,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.categoryName,
        ),
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
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

    if (_photos.isEmpty) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons.photo_library_outlined,
                size: 72,
              ),
              const SizedBox(height: 16),
              Text(
                'No ${widget.categoryName.toLowerCase()} '
                'photos found.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
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
      itemCount: _photos.length,
      itemBuilder: (
        context,
        index,
      ) {
        final photo =
            _photos[index];

        return GestureDetector(
          onTap: () {
            _openPhoto(index);
          },
          child: Hero(
            tag: photo.id,
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
                  child:
                      CircularProgressIndicator(),
                );
              },
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
          ),
        );
      },
    );
  }
}