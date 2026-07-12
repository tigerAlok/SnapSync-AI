import 'package:flutter/material.dart';
import 'similar_photos_screen.dart';
import 'duplicate_groups_screen.dart';
import 'find_my_photos_screen.dart';
import 'semantic_search_screen.dart';
import 'categories/categories_screen.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Discover your photos',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),

        const SizedBox(height: 8),

        Text(
          'Use AI to find photos across all rooms '
          'you have access to.',
          style: Theme.of(context)
              .textTheme
              .bodyLarge,
        ),

        const SizedBox(height: 28),

        // -----------------------------------------
        // FIND MY PHOTOS
        // -----------------------------------------

        _FeatureCard(
          icon: Icons.face_retouching_natural,
          title: 'Find My Photos',
          description:
              'Use a reference selfie to find '
              'photos you may appear in.',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const FindMyPhotosScreen(),
              ),
            );
          },
        ),

        const SizedBox(height: 16),

        // -----------------------------------------
        // AI SEMANTIC SEARCH
        // -----------------------------------------

        _FeatureCard(
          icon: Icons.search,
          title: 'AI Photo Search',
          description:
              'Search with phrases like '
              '"photos on stage", "birthday cake", '
              'or "group photos".',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const SemanticSearchScreen(),
              ),
            );
          },
        ),

        const SizedBox(height: 16),



        const SizedBox(height: 16),

        _FeatureCard(
          icon: Icons.category_outlined,
          title: 'Categories',
          description:
              'Browse photos grouped into People, Nature, '
              'Food, Documents, Animals, and Vehicles.',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const CategoriesScreen(),
              ),
            );
          },
        ),

        // -----------------------------------------
        // SMART FILTERS
        // -----------------------------------------

        _FeatureCard(
          icon: Icons.tune,
          title: 'Smart Filters',
          description:
              'Temporarily filter photos by room, '
              'date, uploader, and more.',
          onTap: () {
            // Smart Filters will be connected later.
          },
        ),

        const SizedBox(height: 16),

        // -----------------------------------------
        // SIMILAR PHOTOS
        // -----------------------------------------

        _FeatureCard(
          icon: Icons.collections_outlined,
          title: 'Similar Photos',
          description:
              'Choose a photo and find visually similar images.',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const SimilarPhotosScreen(),
              ),
            );
          },
        ),

        const SizedBox(height: 16),

        // DUPLICATE GROUPS
        _FeatureCard(
          icon: Icons.copy_all_outlined,
          title: 'Duplicate Groups',
          description:
              'Automatically find groups of duplicate and near-duplicate photos.',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const DuplicateGroupsScreen(),
              ),
            );
          },
        ),


      ],
    );
  }
}


class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: Theme.of(context)
                      .colorScheme
                      .onPrimaryContainer,
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight:
                                FontWeight.bold,
                          ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      description,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.chevron_right,
              ),
            ],
          ),
        ),
      ),
    );
  }
}