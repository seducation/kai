import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/appwrite_service.dart';
import 'package:provider/provider.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  String _productName = '';
  String _productDescription = '';
  double _productPrice = 0.0;
  String _productLocation = '';
  File? _productImage;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _productImage = File(pickedFile.path);
      });
    }
  }

  void _addProduct() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final navigator = Navigator.of(context);
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      try {
        final appwriteService = context.read<AppwriteService>();
        final profiles = await appwriteService.getUserProfiles(ownerId: (await appwriteService.getUser())!.$id);
        final profileId = profiles.rows.first.$id;

        // Note: You'll need to handle the image upload to Appwrite Storage
        // and get the file ID to store in the product document.
        // This part is not fully implemented here.

        await appwriteService.createProduct(
          name: _productName,
          description: _productDescription,
          price: _productPrice,
          profileId: profileId,
          location: _productLocation,
          // You would pass the image file ID here
        );

        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Product added successfully!')),
        );
        navigator.pop();
      } catch (e) {
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Failed to add product: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Product'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (_productImage != null)
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: FileImage(_productImage!),
                        fit: BoxFit.cover,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Product Name'),
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter a product name' : null,
                  onSaved: (value) => _productName = value ?? '',
                ),
                TextFormField(
                  decoration:
                      const InputDecoration(labelText: 'Product Description'),
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter a product description' : null,
                  onSaved: (value) => _productDescription = value ?? '',
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.number,
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter a price' : null,
                  onSaved: (value) =>
                      _productPrice = double.tryParse(value ?? '') ?? 0.0,
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Location'),
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter a location' : null,
                  onSaved: (value) => _productLocation = value ?? '',
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _addProduct,
                  child: const Text('Add Product'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
