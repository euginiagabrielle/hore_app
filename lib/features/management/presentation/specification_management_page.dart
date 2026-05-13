import 'package:flutter/material.dart';
import '../data/specification_repository.dart';

class SpecificationManagementPage extends StatefulWidget {
  const SpecificationManagementPage({super.key});

  @override
  State<SpecificationManagementPage> createState() => _SpecificationManagementPageState();
}

class _SpecificationManagementPageState extends State<SpecificationManagementPage> {
  final SpecificationRepository _repository = SpecificationRepository();

  final Map<String, String> _dataTypeLabels = {
    'String': 'Kata / Tulisan (String)',
    'Numeric': 'Angka / Nomor (Numeric)',
    'Boolean': 'Pilihan (Ya / Tidak)',
  };

  List<Map<String, dynamic>> _specifications = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchSpecification();
    });
  }

  Future<void> _fetchSpecification() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final specs = await _repository.getSpecifications();
      final cats = await _repository.getCategoriesForDropdown();

      if (mounted) {
        setState(() {
          _specifications = specs;
          _categories = cats;
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

  void _showFormDialog({Map<String, dynamic>? data}) {
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Buat Kategori terlebih!")));
      return;
    }

    final bool isEdit = data != null;
    final TextEditingController nameController = TextEditingController(text: isEdit ? data['specification_name'] : '');
    final TextEditingController unitController = TextEditingController(text: isEdit ? (data['unit'] ?? '') : '');

    int? selectedCategoryId = isEdit ? data['categories_id'] : null;
    String? selectedDataType = isEdit ? data['data_type'] : null;

    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? "Edit Spesifikasi" : "Tambah Spesifikasi"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: selectedCategoryId,
                  decoration: const InputDecoration(labelText: "Kategori Produk",  border: OutlineInputBorder()),
                  items: _categories.map((cat) => DropdownMenuItem<int>(
                    value: cat['categories_id'],
                    child: Text(cat['category_name'])
                  )).toList(), 
                  onChanged: (val) => setDialogState(() => selectedCategoryId = val),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Nama (cth: Daya, Warna)", border: OutlineInputBorder()),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: selectedDataType,
                  decoration: const InputDecoration(labelText: "Jenis Input (Tipe Data)", border: OutlineInputBorder()),
                  items: _dataTypeLabels.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(), 
                  onChanged: (val) => setDialogState(() => selectedDataType = val),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: unitController,
                  decoration: const InputDecoration(labelText: "Satuan (cth: PK, Watt) - Opsional", border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: isSaving ? null : () => Navigator.pop(context), child: const Text("Batal")),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                if (selectedCategoryId == null || nameController.text.trim().isEmpty || selectedDataType == null) return;
                setDialogState(() => isSaving = true);

                try {
                  if (isEdit) {
                    await _repository.updateSpecifiction(data['specification_id'], selectedCategoryId!, nameController.text.trim(), selectedDataType!, unitController.text.trim());
                  } else {
                    await _repository.addSpecification(selectedCategoryId!, nameController.text.trim(), selectedDataType!, unitController.text.trim());
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                    _fetchSpecification();
                  }
                } catch (e) {
                  setDialogState(() => isSaving = false);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              },
              child: isSaving ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("Simpan"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manajemen Spesifikasi"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Data",
            onPressed: _fetchSpecification,
          ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _fetchSpecification, 
            child: ListView(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
              children: [
                _specifications.isEmpty
                  ? const Center(child: Text("Belum ada spesifikasi."))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraints.maxWidth),
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
                              columns: const [
                                DataColumn(label: Text('Kategori', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Spesifikasi', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Jenis Input', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Satuan', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold))),
                              ], 
                              rows: _specifications.asMap().entries.map((entry) {
                                final item = entry.value;
                                final String catName = item['categories']?['category_name'] ?? '-';

                                return DataRow(
                                  color: WidgetStateProperty.all(entry.key.isOdd ? Colors.grey.shade50 : Colors.white),
                                  cells: [
                                    DataCell(Text(catName)),
                                    DataCell(Text(item['specification_name'])),
                                    DataCell(Text(_dataTypeLabels[item['data_type']] ?? item['data_type'])),
                                    DataCell(Text(item['unit'] ?? '-')),
                                    DataCell(IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.orange, size: 20),
                                      onPressed: () => _showFormDialog(data: item),
                                    )),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        );
                      },
                    ),
              ],
            ),
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormDialog(),
        icon: const Icon(Icons.add),
        label: const Text("Tambah Spesifikasi"),
      ),
    );
  }
}