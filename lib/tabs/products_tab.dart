import 'package:flutter/material.dart';
import 'package:my_app/community_screen_widget/product_grid.dart';

class ProductsTab extends StatelessWidget {
  final String profileId;

  const ProductsTab({super.key, required this.profileId});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ProductGrid(profileId: profileId),
      ),
    );
  }
}
