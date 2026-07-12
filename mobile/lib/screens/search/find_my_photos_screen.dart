import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/photo/photo_model.dart';
import '../../providers/photo/photo_provider.dart';
import '../../providers/room/room_provider.dart';
import '../../services/api/api_service.dart';
import 'face_search_results_screen.dart';


class FindMyPhotosScreen
    extends ConsumerStatefulWidget {
  const FindMyPhotosScreen({
    super.key,
  });

  @override
  ConsumerState<FindMyPhotosScreen> createState() =>
      _FindMyPhotosScreenState();
}


class _FindMyPhotosScreenState
    extends ConsumerState<FindMyPhotosScreen> {
  final ImagePicker _picker = ImagePicker();
  final ApiService _apiService = ApiService();

  XFile? _selectedSelfie;

  bool _consentAccepted = false;
  bool _isSearching = false;

  String _searchStatus = '';


  // -------------------------------------------------
  // PICK SELFIE
  // -------------------------------------------------

  Future<void> _pickSelfie(
    ImageSource source,
  ) async {
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      preferredCameraDevice:
          CameraDevice.front,
    );

    if (image == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedSelfie = image;
    });
  }


  // -------------------------------------------------
  // IMAGE SOURCE OPTIONS
  // -------------------------------------------------

  void _showImageSourceOptions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(
              bottom: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_outlined,
                  ),
                  title: const Text(
                    'Take a selfie',
                  ),
                  onTap: () {
                    Navigator.pop(
                      bottomSheetContext,
                    );

                    _pickSelfie(
                      ImageSource.camera,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                  ),
                  title: const Text(
                    'Choose from gallery',
                  ),
                  onTap: () {
                    Navigator.pop(
                      bottomSheetContext,
                    );

                    _pickSelfie(
                      ImageSource.gallery,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  // -------------------------------------------------
  // START FACE SEARCH
  // -------------------------------------------------

  Future<void> _startSearch() async {
    if (!_consentAccepted ||
        _selectedSelfie == null ||
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Join or create a room before searching for photos.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _isSearching = true;
      _searchStatus =
          'Preparing your photo library...';
    });

    try {
      // ---------------------------------------------
      // STEP 1: BACKFILL OLD PHOTOS
      // ---------------------------------------------

      final processedCount = await ref
          .read(
            photoBackfillControllerProvider.notifier,
          )
          .backfillRooms(
            roomIds: roomIds,
          );

      debugPrint(
        'Backfill completed. '
        '$processedCount old photo(s) processed.',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _searchStatus =
            'Searching for your photos...';
      });


      // ---------------------------------------------
      // STEP 2: REFERENCE SELFIE SEARCH
      // ---------------------------------------------

      final result =
          await _apiService.uploadReferenceSelfie(
        selfie: _selectedSelfie!,
        roomIds: roomIds,
      );

      final rawMatches =
          result['matches'] as List<dynamic>? ?? [];

      final List<PhotoModel> matchedPhotos = [];


      // ---------------------------------------------
      // STEP 3: LOAD MATCHED PHOTO DOCUMENTS
      // ---------------------------------------------

      for (final rawMatch in rawMatches) {
        if (rawMatch is! Map) {
          continue;
        }

        final match =
            Map<String, dynamic>.from(
          rawMatch,
        );

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
        _isSearching = false;
        _searchStatus = '';
      });


      // ---------------------------------------------
      // STEP 4: OPEN RESULTS
      // ---------------------------------------------

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              FaceSearchResultsScreen(
            photos: matchedPhotos,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSearching = false;
        _searchStatus = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Search failed: $error',
          ),
        ),
      );
    }
  }


  // -------------------------------------------------
  // UI
  // -------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final canStart =
        _consentAccepted &&
        _selectedSelfie != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Find My Photos',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Find photos you appear in',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),

          const SizedBox(
            height: 8,
          ),

          const Text(
            'Choose a clear reference selfie. '
            'SnapSync AI will use it to search '
            'photos from rooms you are allowed '
            'to access.',
          ),

          const SizedBox(
            height: 28,
          ),


          // -----------------------------------------
          // SELFIE PREVIEW
          // -----------------------------------------

          Center(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(24),
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
              ),
              clipBehavior: Clip.antiAlias,
              child: _selectedSelfie == null
                  ? const Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.face_outlined,
                          size: 70,
                        ),
                        SizedBox(
                          height: 12,
                        ),
                        Text(
                          'No selfie selected',
                        ),
                      ],
                    )
                  : Image.file(
                      File(
                        _selectedSelfie!.path,
                      ),
                      fit: BoxFit.cover,
                    ),
            ),
          ),

          const SizedBox(
            height: 20,
          ),


          // -----------------------------------------
          // CHOOSE SELFIE BUTTON
          // -----------------------------------------

          OutlinedButton.icon(
            onPressed: _isSearching
                ? null
                : _showImageSourceOptions,
            icon: const Icon(
              Icons.add_a_photo_outlined,
            ),
            label: Text(
              _selectedSelfie == null
                  ? 'Choose Reference Selfie'
                  : 'Change Selfie',
            ),
          ),

          const SizedBox(
            height: 28,
          ),


          // -----------------------------------------
          // PRIVACY INFORMATION
          // -----------------------------------------

          Card(
            child: Padding(
              padding: const EdgeInsets.all(
                16,
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.privacy_tip_outlined,
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  Expanded(
                    child: Text(
                      'The reference selfie is used '
                      'for finding likely matches. '
                      'Search results are temporary '
                      'and do not modify your main '
                      'Gallery.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(
            height: 16,
          ),


          // -----------------------------------------
          // CONSENT
          // -----------------------------------------

          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _consentAccepted,
            controlAffinity:
                ListTileControlAffinity.leading,
            title: const Text(
              'I agree to use this selfie '
              'for face matching.',
            ),
            subtitle: const Text(
              'You will be able to remove '
              'face-related data from your account.',
            ),
            onChanged: _isSearching
                ? null
                : (value) {
                    setState(() {
                      _consentAccepted =
                          value ?? false;
                    });
                  },
          ),

          const SizedBox(
            height: 24,
          ),


          // -----------------------------------------
          // SEARCH BUTTON
          // -----------------------------------------

          FilledButton.icon(
            onPressed:
                canStart && !_isSearching
                    ? _startSearch
                    : null,
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
            label: Padding(
              padding:
                  const EdgeInsets.symmetric(
                vertical: 14,
              ),
              child: Text(
                _isSearching
                    ? _searchStatus
                    : 'Find My Photos',
              ),
            ),
          ),
        ],
      ),
    );
  }
}