import 'package:flutter/material.dart';

import 'category_photos_screen.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({
    super.key,
  });

  static const List<_CategoryItem> _categories = [
    _CategoryItem(
      name: 'People',
      value: 'people',
      icon: Icons.people_outline,
    ),
    _CategoryItem(
      name: 'Nature',
      value: 'nature',
      icon: Icons.landscape_outlined,
    ),
    _CategoryItem(
      name: 'Food',
      value: 'food',
      icon: Icons.restaurant_outlined,
    ),
    _CategoryItem(
      name: 'Documents',
      value: 'documents',
      icon: Icons.description_outlined,
    ),
    _CategoryItem(
      name: 'Animals',
      value: 'animals',
      icon: Icons.pets_outlined,
    ),
    _CategoryItem(
      name: 'Vehicles',
      value: 'vehicles',
      icon: Icons.directions_car_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Categories',
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.15,
        ),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];

          return Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CategoryPhotosScreen(
                      categoryName:
                          category.name,
                      categoryValue:
                          category.value,
                    ),
                  ),
                );
              },
              child: Padding(
                padding:
                    const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Icon(
                      category.icon,
                      size: 48,
                      color: Theme.of(context)
                          .colorScheme
                          .primary,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      category.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight:
                                FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryItem {
  final String name;
  final String value;
  final IconData icon;

  const _CategoryItem({
    required this.name,
    required this.value,
    required this.icon,
  });
}