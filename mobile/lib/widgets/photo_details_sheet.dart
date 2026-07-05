import 'package:flutter/material.dart';

import '../models/photo/photo_model.dart';

class PhotoDetailsSheet extends StatelessWidget {
  final PhotoModel photo;
  final String roomName;

  const PhotoDetailsSheet({
    super.key,
    required this.photo,
    required this.roomName,
  });

  static Future<void> show(
    BuildContext context, {
    required PhotoModel photo,
    required String roomName,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return PhotoDetailsSheet(
          photo: photo,
          roomName: roomName,
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();

    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final year = localDate.year;

    final hour = localDate.hour.toString().padLeft(2, '0');
    final minute = localDate.minute.toString().padLeft(2, '0');

    return '$day/$month/$year at $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final uploaderName =
        photo.uploaderName?.trim().isNotEmpty == true
            ? photo.uploaderName!
            : 'Unknown user';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          24,
          8,
          24,
          32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Photo Details',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),

            const SizedBox(height: 24),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.person_outline,
              ),
              title: const Text('Uploaded by'),
              subtitle: Text(uploaderName),
            ),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.schedule_outlined,
              ),
              title: const Text('Uploaded on'),
              subtitle: Text(
                _formatDate(photo.createdAt),
              ),
            ),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.groups_outlined,
              ),
              title: const Text('Room'),
              subtitle: Text(roomName),
            ),
          ],
        ),
      ),
    );
  }
}