import 'package:flutter/material.dart';

import '../../models/photo/photo_model.dart';
import '../../services/download/photo_download_service.dart';

class PhotoViewerScreen extends StatefulWidget {
  final List<PhotoModel> photos;
  final int initialIndex;

  const PhotoViewerScreen({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<PhotoViewerScreen> createState() =>
      _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  bool _isDownloading = false;

  final PhotoDownloadService _downloadService =
      PhotoDownloadService();

  @override
  void initState() {
    super.initState();

    _currentIndex = widget.initialIndex;

    _pageController = PageController(
      initialPage: widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _downloadCurrentPhoto() async {
    if (_isDownloading) {
      return;
    }

    setState(() {
      _isDownloading = true;
    });

    try {
      final currentPhoto = widget.photos[_currentIndex];

      await _downloadService.savePhotoToGallery(
        currentPhoto.imageUrl,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Photo saved to gallery.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Download failed: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,

        title: Text(
          '${_currentIndex + 1} / ${widget.photos.length}',
        ),

        actions: [
          IconButton(
            tooltip: 'Save to gallery',
            onPressed:
                _isDownloading ? null : _downloadCurrentPhoto,
            icon: _isDownloading
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
      ),

      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.photos.length,

        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },

        itemBuilder: (context, index) {
          final photo = widget.photos[index];

          final caption =
              photo.aiCaption?.trim();

          return Column(
            children: [
              Expanded(
                child: Center(
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,

                    child: Hero(
                      tag: photo.id,

                      child: Image.network(
                        photo.imageUrl,
                        fit: BoxFit.contain,

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
                                CircularProgressIndicator(
                              color: Colors.white,
                            ),
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
                              color: Colors.white,
                              size: 60,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              if (caption != null &&
                  caption.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    14,
                    20,
                    20,
                  ),
                  color: Colors.black,
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        color: Colors.white70,
                        size: 20,
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: Text(
                          caption,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}