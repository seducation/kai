import 'package:flutter/material.dart';
import 'package:my_app/community_screen_widget/product_grid.dart';

class ProductsTab extends StatelessWidget {
  const ProductsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ProductGrid(),
      ),
    );
  }
}
