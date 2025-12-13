import 'package:flutter/material.dart';
import 'package:my_app/appwrite_service.dart';
import 'package:my_app/models/product.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProductGrid extends StatefulWidget {
  final String? profileId;

  const ProductGrid({super.key, this.profileId});

  @override
  State<ProductGrid> createState() => _ProductGridState();
}

class _ProductGridState extends State<ProductGrid> {
  late Future<List<Product>> _productsFuture;
  late AppwriteService _appwriteService;

  @override
  void initState() {
    super.initState();
    _appwriteService = Provider.of<AppwriteService>(context, listen: false);
    _productsFuture = _getProducts();
  }

  @override
  void didUpdateWidget(ProductGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId) {
      setState(() {
        _productsFuture = _getProducts();
      });
    }
  }

  Future<List<Product>> _getProducts() async {
    debugPrint('Fetching products for profileId: ${widget.profileId}');
    try {
      final response = widget.profileId != null
          ? await _appwriteService.getProductsByProfile(widget.profileId!)
          : await _appwriteService.getProducts();
      debugPrint('Appwrite response received. Total documents: ${response.total}');
      for (var row in response.rows) {
          debugPrint('Row data: ${row.data}');
      }
      return response.rows
          .map((row) => Product.fromMap(row.data, row.$id))
          .toList();
    } catch (e) {
      debugPrint('Error fetching products: $e');
      throw Exception('Failed to load products. Please try again.');
    }
  }

  void _retry() {
    setState(() {
      _productsFuture = _getProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Product>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _retry,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('No products found. Add a new product to see it here!'),
          );
        }

        final products = snapshot.data!;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: products.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            mainAxisSpacing: 10.0,
            crossAxisSpacing: 10.0,
          ),
          itemBuilder: (context, index) {
            return ProductCard(product: products[index]);
          },
        );
      },
    );
  }
}

class ProductCard extends StatelessWidget {
  final Product product;

  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final appwriteService = Provider.of<AppwriteService>(context, listen: false);

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      elevation: 5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15.0),
                topRight: Radius.circular(15.0),
              ),
              child: product.imageId != null
                  ? CachedNetworkImage(
                      imageUrl: appwriteService.getFileViewUrl(product.imageId!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) =>
                          const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.error),
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.image, size: 50, color: Colors.grey),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Roboto',
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  '\u20b9${product.price}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Roboto',
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  product.location,
                  style: const TextStyle(
                    fontSize: 12.0,
                    fontFamily: 'Roboto',
                  ),
                ),
                const SizedBox(height: 4.0),
                const Text(
                  'Free delivery',
                  style: TextStyle(
                    fontSize: 12.0,
                    fontFamily: 'Roboto',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
