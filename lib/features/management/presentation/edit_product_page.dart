import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/product_repository.dart';
import '../../../core/utils/error_handler.dart';

class EditProductPage extends StatefulWidget {
  final Map<String, dynamic> product;

  const EditProductPage({super.key, required this.product});

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final  _repo = ProductRepository();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _stockController;
  late TextEditingController _priceController;

  List<Map<String, dynamic>> _categories = [];
  int? _selectedCategoryId;

  XFile? _selectedImage;
  Uint8List? _imageBytes;
  String? _existingImageUrl;
  bool _isLoading = false;

  List<Map<String, dynamic>> _specifications = [];
  final Map<int, TextEditingController> _specControllers = {};
  bool _isLoadingSpecs = false;
  
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product['product_name']);
    _codeController = TextEditingController(text: widget.product['product_code']);
    _stockController = TextEditingController(text: widget.product['product_stock'].toString());
    _priceController = TextEditingController(text: widget.product['product_price'].toString());
    _existingImageUrl = widget.product['product_picture_url'];

    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final categories = await _repo.getCategories();
      setState(() {
        _categories = categories;
        _selectedCategoryId = widget.product['category_id'] is int
          ? widget.product['category_id']
          : int.tryParse(widget.product['category_id'].toString());
      });

      if (_selectedCategoryId != null) {
        await _loadSpecsForCategory(_selectedCategoryId!, isInitialLoad: true);
      }
    } catch (e) {
      debugPrint("Error load initial: $e");
    }
  }

  Future<void> _loadSpecsForCategory(int categoryId, {bool isInitialLoad = false}) async {
    setState(() => _isLoadingSpecs = true);
    try {
      final specs = await _repo.getSpecificationsByCategory(categoryId);

      Map<int,  String> oldValues = {};
      if (isInitialLoad) {
        oldValues = await _repo.getProductSpecValues(widget.product['product_id']);
      }

      setState(() {
        _specifications = specs;
        _specControllers.clear();
        for (var spec in specs) {
          final int specId = spec['specification_id'];
          _specControllers[specId] = TextEditingController(text: oldValues[specId] ?? '');
        }
      });
    } catch (e) {
      debugPrint("Error specs: $e");
    } finally {
      setState(() => _isLoadingSpecs = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _selectedImage = picked;
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) return;

    setState(() => _isLoading = true);

    try {
      Map<int, String> specValueToSave = {};
      _specControllers.forEach((specId, controller) {
        if (controller.text.isNotEmpty) specValueToSave[specId] = controller.text;
      });

      await _repo.updateProduct(
        productId: widget.product['product_id'], 
        name: _nameController.text, 
        categoryId: _selectedCategoryId!, 
        stock: int.parse(_stockController.text), 
        price: double.parse(_priceController.text),
        newImageBytes: _imageBytes,
        newImageExtension: _selectedImage?.name.split('.').last, 
        specificationValues: specValueToSave,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produk berhasil diupdate!')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorHandler.getMessage(e)), backgroundColor: Colors.red,));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Produk")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(color: Colors.grey[200], border: Border.all(color: Colors.grey)),
                  child: _imageBytes != null
                    ? (kIsWeb ? Image.network(_selectedImage!.path, fit: BoxFit.cover) : Image.file(File(_selectedImage!.path), fit: BoxFit.cover))
                    : (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                      ? Image.network(_existingImageUrl!, fit: BoxFit.cover, 
                        errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Text(
                                "Offline: Gagal memuat foto lama", 
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.red),
                              ),
                            );
                          },
                        )
                      : const Center(child: Text("Ketuk untuk ganti foto")),
                ),
              ),

              const SizedBox(height: 16),

              // Main data
              TextFormField(
                controller: _codeController, 
                readOnly: true, 
                decoration: InputDecoration(labelText: "Kode Produk *Tidak bisa diedit", filled: true, fillColor: Colors.grey[200], border: const OutlineInputBorder())
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Nama Produk", border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextFormField(controller: _stockController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Stok", border: OutlineInputBorder()))),
                  const SizedBox(height: 12),
                  Expanded(child: TextFormField(controller: _priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Harga", border: OutlineInputBorder()))),
                ],
              ),
              const SizedBox(height: 16),

              // Category & Specification
              if (_categories.isNotEmpty)
                DropdownButtonFormField<int>(
                  initialValue: _selectedCategoryId,
                  decoration: const InputDecoration(labelText: "Kategori", border: OutlineInputBorder()),
                  items: _categories.map((cat) => DropdownMenuItem<int>(value: cat['categories_id'], child: Text(cat['category_name'].toString()))).toList(), 
                  onChanged: (val) {
                    setState(() => _selectedCategoryId = val);
                    _loadSpecsForCategory(val!);
                  },
                ),
              
              const SizedBox(height: 16),
              if (_isLoadingSpecs) const Center(child: CircularProgressIndicator())
              else if (_specifications.isNotEmpty) ...[
                const Divider(),
                const Text("Spesifikasi Produk:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                ..._specifications.map((spec) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: TextFormField(
                      controller: _specControllers[spec['specification_id']],
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                      decoration: InputDecoration(labelText: spec['specification_name'], border: const OutlineInputBorder(), filled: true, fillColor: Colors.blue[50]),
                    ),
                  );
                }),
              ],

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.orange), 
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Simpan Perubahan", style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}