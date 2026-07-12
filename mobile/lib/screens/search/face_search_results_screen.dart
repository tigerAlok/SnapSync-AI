import 'package:flutter/material.dart';

import '../../models/photo/photo_model.dart';
import '../rooms/photo_viewer_screen.dart';

class FaceSearchResultsScreen extends StatelessWidget {
  final List<PhotoModel> photos;

  const FaceSearchResultsScreen({
    super.key,
    required this.photos,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${photos.length} Matching Photo(s)',
        ),
      ),
      body: photos.isEmpty
          ? const _EmptyResultsView()
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: photos.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemBuilder: (
                context,
                index,
              ) {
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
                  child: Hero(
                    tag: photo.id,
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(10),
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
                          return Container(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            child: const Center(
                              child: Icon(
                                Icons
                                    .broken_image_outlined,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _EmptyResultsView extends StatelessWidget {
  const _EmptyResultsView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.face_outlined,
              size: 72,
            ),
            SizedBox(height: 16),
            Text(
              'No matching photos found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try using another clear reference selfie.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}