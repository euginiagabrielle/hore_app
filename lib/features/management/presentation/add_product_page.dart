import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/product_repository.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _repo = ProductRepository();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _stockController = TextEditingController();
  final _priceController = TextEditingController();

  // State for categories
  List<Map<String, dynamic>> _categories = [];
  int? _selectedCategoryId;
  File? _selectedImage;
  bool _isLoading = false;

  // State for specification
  List<Map<String, dynamic>> _specifications = [];
  // Key: specification_id, Value: TextEditingController
  final Map<int, TextEditingController> _specControllers = {};
  bool _isLoadingSpecs = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _stockController.dispose();
    _priceController.dispose();
    for (var controller in _specControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final data = await _repo.getCategories();
      setState(() => _categories = data);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal load kategori: $e')));
    }
  }

  // Load specification based on chosen category
  Future<void> _onCategoryChanged(int? newCategoryId) async {
    if (newCategoryId == null) return;

    setState(() {
      _selectedCategoryId = newCategoryId;
      _isLoadingSpecs = true;
      _specifications.clear();
      _specControllers.clear();
    });

    try {
      final specs = await _repo.getSpecificationsByCategory(newCategoryId);
      setState(() {
        _specifications = specs;
        // Controller for each specification
        for (var spec in specs) {
          final int specId = spec['specification_id'];
          _specControllers[specId] = TextEditingController();
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal load spesifikasi: $e')));
    } finally {
      setState(() => _isLoadingSpecs = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto produk belum terisi.')),
      );
      return;
    }
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kategori belum terpilih.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      Map<int, String> specValueToSave = {};
      _specControllers.forEach((specId, controller) {
        if (controller.text.isNotEmpty) {
          specValueToSave[specId] = controller.text;
        }
      });

      await _repo.addProduct(
        name: _nameController.text,
        code: _codeController.text,
        categoryId: _selectedCategoryId!,
        stock: int.parse(_stockController.text),
        price: double.parse(_priceController.text),
        imageFile: _selectedImage!,
        specificationValues: specValueToSave,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produk berhasil disimpan & QR dibuat.'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tambah Produk Baru")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image input
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _selectedImage != null
                      ? Image.file(_selectedImage!, fit: BoxFit.cover)
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                            Text("Tekan untuk upload gambar"),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Form input
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: "Kode Produk",
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val!.isEmpty ? 'Kode produk wajib diisi' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Nama Produk",
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val!.isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Stok Barang",
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) =>
                          val!.isEmpty ? "Stok wajib diisi" : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Harga Jual",
                        prefixText: "Rp ",
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) =>
                          val!.isEmpty ? "Harga wajib diisi" : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _categories.isEmpty
                  ? const Text(
                      "Loading kategori...",
                      style: TextStyle(color: Colors.red),
                    )
                  : DropdownButtonFormField<int>(
                      initialValue: _selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: "Kategori",
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((cat) {
                        final int catId = cat['categories_id'] is int
                            ? cat['categories_id']
                            : int.tryParse(cat['categories_id'].toString()) ??
                                  0;
                        return DropdownMenuItem<int>(
                          value: catId,
                          child: Text(cat['category_name'].toString()),
                        );
                      }).toList(),
                      onChanged: _onCategoryChanged,
                    ),

              const SizedBox(height: 16),

              // Specification values input
              if (_isLoadingSpecs)
                const Center(child: CircularProgressIndicator())
              else if (_specifications.isNotEmpty) ...[
                const Divider(thickness: 2),
                const Text(
                  "Spesifikasi Produk:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),

                ..._specifications.map((spec) {
                  final int specId = spec['specification_id'];
                  final String specName = spec['specification_name'];
                  final String unit =
                      spec['unit'] != null && spec['unit'].toString().isNotEmpty
                      ? "(${spec['unit']})"
                      : "";

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: TextFormField(
                      controller: _specControllers[specId],
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                      decoration: InputDecoration(
                        labelText: "$specName $unit",
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.blue[50],
                      ),
                    ),
                  );
                }),
              ],

              const SizedBox(height: 24),

              // Save button
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blueAccent,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Simpan Produk & Generate QR",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
