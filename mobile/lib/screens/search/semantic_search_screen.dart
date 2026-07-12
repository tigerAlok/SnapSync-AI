import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/photo/photo_model.dart';
import '../../providers/photo/photo_provider.dart';
import '../../providers/room/room_provider.dart';
import '../../services/api/api_service.dart';
import '../rooms/photo_viewer_screen.dart';


class SemanticSearchScreen
    extends ConsumerStatefulWidget {
  const SemanticSearchScreen({
    super.key,
  });

  @override
  ConsumerState<SemanticSearchScreen>
      createState() =>
          _SemanticSearchScreenState();
}


class _SemanticSearchScreenState
    extends ConsumerState<SemanticSearchScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  final ApiService _apiService =
      ApiService();

  List<PhotoModel> _results = [];

  bool _isSearching = false;

  String? _errorMessage;

  bool _hasSearched = false;


  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }


  Future<void> _search() async {
    final query =
        _searchController.text.trim();

    if (query.isEmpty ||
        _isSearching) {
      return;
    }

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
      setState(() {
        _hasSearched = true;
        _results = [];
        _errorMessage =
            'Join or create a room before searching.';
      });

      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _hasSearched = true;
    });

    try {
      final response =
          await _apiService.searchPhotos(
        query: query,
        roomIds: roomIds,
      );

      final rawMatches =
          response['matches']
                  as List<dynamic>? ??
              [];

      final List<PhotoModel>
          matchedPhotos = [];

      // Results are fetched in backend ranking order.
      // This preserves semantic relevance order.
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
          matchedPhotos.add(
            photo,
          );
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _results = matchedPhotos;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _results = [];
        _errorMessage =
            'Search failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
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
          photos: _results,
          initialIndex: index,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Photo Search',
        ),
      ),

      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.all(16),
            child: SearchBar(
              controller:
                  _searchController,

              hintText:
                  'Try "birthday cake" or "photos on stage"',

              leading: const Icon(
                Icons.search,
              ),

              trailing: [
                if (_searchController
                    .text
                    .isNotEmpty)
                  IconButton(
                    tooltip: 'Clear',
                    onPressed: () {
                      _searchController.clear();

                      setState(() {
                        _results = [];
                        _errorMessage = null;
                        _hasSearched = false;
                      });
                    },
                    icon: const Icon(
                      Icons.close,
                    ),
                  ),
              ],

              onChanged: (_) {
                setState(() {});
              },

              onSubmitted: (_) {
                _search();
              },
            ),
          ),

          Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 16,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    _isSearching
                        ? null
                        : _search,
                icon: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.auto_awesome,
                      ),
                label: Text(
                  _isSearching
                      ? 'Searching...'
                      : 'Search Photos',
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }


  Widget _buildContent() {
    if (_isSearching &&
        _results.isEmpty) {
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

    if (!_hasSearched) {
      return const Center(
        child: Padding(
          padding:
              EdgeInsets.all(24),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Icon(
                Icons.image_search_outlined,
                size: 72,
              ),
              SizedBox(height: 16),
              Text(
                'Describe the photo you are looking for.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return const Center(
        child: Text(
          'No matching photos found.',
        ),
      );
    }

    return GridView.builder(
      padding:
          const EdgeInsets.all(4),
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _results.length,
      itemBuilder: (
        context,
        index,
      ) {
        final photo =
            _results[index];

        return GestureDetector(
          onTap: () {
            _openPhoto(
              index,
            );
          },
          child: Hero(
            tag:photo.id,
                
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
        );
      },
    );
  }
}