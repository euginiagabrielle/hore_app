import 'package:flutter/material.dart';
import '../data/category_repository.dart';

class CategoryManagementPage extends StatefulWidget {
  const CategoryManagementPage({super.key});

  @override
  State<CategoryManagementPage> createState() => _CategoryManagementPageState();
}

class _CategoryManagementPageState extends State<CategoryManagementPage> {
  final CategoryRepository _repository = CategoryRepository();
  
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchCategories();
    });
  }

  Future<void> _fetchCategories() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final data = await _repository.getCategories();
          
      if (mounted) {
        setState(() {
          _categories = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _showCategoryDialog({Map<String, dynamic>? category}) {
    final bool isEdit = category != null;
    final TextEditingController nameController = TextEditingController(text: isEdit ? category['category_name'] : '');
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? "Edit Kategori" : "Tambah Kategori Baru"),
              content: TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Nama Kategori (contoh: Minuman)",
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text("Batal"),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (nameController.text.trim().isEmpty) return;

                    setDialogState(() => isSaving = true);

                    try {
                      if (isEdit) {
                        await _repository.updateCategory(
                          category['categories_id'], 
                          nameController.text.trim()
                        );
                      } else {
                        await _repository.addCategory(nameController.text.trim());
                      }
                      
                      if (context.mounted) {
                        Navigator.pop(context);
                        _fetchCategories(); 
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(isEdit ? 'Kategori diperbarui!' : 'Kategori ditambahkan!'), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      setDialogState(() => isSaving = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                      }
                    }
                  },
                  child: isSaving ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("Simpan"),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manajemen Kategori"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Data",
            onPressed: _fetchCategories,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchCategories,
              child: ListView(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
                children: [
                  _categories.isEmpty
                      ? const Center(child: Text("Belum ada kategori."))
                      : DataTable(
                          headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
                          columns: const [
                            DataColumn(label: Text('Nama Kategori', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: _categories.asMap().entries.map((entry) {
                            final item = entry.value;
                            return DataRow(
                              color: WidgetStateProperty.all(entry.key.isOdd ? Colors.grey.shade50 : Colors.white),
                              cells: [
                                DataCell(Text(item['category_name'])),
                                DataCell(IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.orange, size: 20),
                                  onPressed: () => _showCategoryDialog(category: item),
                                  tooltip: "Edit",
                                )),
                              ],
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCategoryDialog(),
        icon: const Icon(Icons.add),
        label: const Text("Tambah Kategori"),
      ),
    );
  }
}