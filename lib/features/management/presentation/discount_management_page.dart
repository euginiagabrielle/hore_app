import 'package:flutter/material.dart';
import '../data/discount_repository.dart';

class DiscountManagementPage extends StatefulWidget {
  const DiscountManagementPage({super.key});

  @override
  State<DiscountManagementPage> createState() => _DiscountManagementPageState();
}

class _DiscountManagementPageState extends State<DiscountManagementPage> {
  final DiscountRepository _repository = DiscountRepository();
  List<Map<String, dynamic>> _discounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchDiscounts();
    });
  }

  Future<void> _fetchDiscounts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final data = await _repository.getDiscounts();
      if (mounted) {
        setState(() {
          _discounts = data;
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
    final bool isEdit = data != null;
    final TextEditingController nameController = TextEditingController(text: isEdit ? data['discount_name'] : '');
    final TextEditingController valueController = TextEditingController(text: isEdit ? data['discount_value'].toString() : '');

    bool isActive = isEdit ? (data['is_discount_active'] == true) : true;
    bool isSaving = false;

    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? "Edit Diskon" : "Tambah Diskon Baru"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Nama Diskon (contoh: Promo Akhir Tahun)",
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: valueController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Nilai Diskon (angka)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text("Status Diskon"),
                  subtitle: Text(isActive ? "Aktif" : "Non-aktif"),
                  value: isActive, 
                  onChanged: (bool value) {
                    setDialogState(() {
                      isActive = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context), 
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                if (nameController.text.trim().isEmpty || valueController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Harap isi semua kolom!")));
                  return;
                }

                final double? parsedValue = double.tryParse(valueController.text.trim());
                if (parsedValue == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nilai diskon harus berupa angka!")));
                  return;
                }

                setDialogState(() => isSaving = true);
                try {
                  if (isEdit) {
                    await _repository.updateDiscount(data['discount_id'], nameController.text.trim(), parsedValue, isActive);
                  } else {
                    await _repository.addDiscount(nameController.text.trim(), parsedValue, isActive);
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                    _fetchDiscounts();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Berhasil disimpan"), backgroundColor: Colors.green));
                  }
                } catch (e) {
                  setDialogState(() => isSaving = false);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
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
        title: const Text("Manajemen Diskon"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Data",
            onPressed: _fetchDiscounts,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchDiscounts,
              child: ListView(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
                children: [
                  _discounts.isEmpty
                      ? const Center(child: Text("Belum ada diskon."))
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
                                  columnSpacing: 20,
                                  columns: const [
                                    DataColumn(label: Text('Nama Diskon', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Nilai', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                  rows: _discounts.asMap().entries.map((entry) {
                                    final item = entry.value;
                                    final bool isActive = item['is_discount_active'] == true;
                                    return DataRow(
                                      color: WidgetStateProperty.all(entry.key.isOdd ? Colors.grey.shade50 : Colors.white),
                                      cells: [
                                        DataCell(Text(item['discount_name'].toString())),
                                        DataCell(Text(item['discount_value'].toString())),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isActive ? Colors.green.shade100 : Colors.red.shade100,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              isActive ? 'Aktif' : 'Non-aktif',
                                              style: TextStyle(
                                                color: isActive ? Colors.green.shade800 : Colors.red.shade800,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
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
        label: const Text("Tambah Diskon"),
      ),
    );
  }
}