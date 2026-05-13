import 'package:flutter/material.dart';
import '../data/customer_repository.dart';

class CustomerManagemtPage extends StatefulWidget {
  const CustomerManagemtPage({super.key});

  @override
  State<CustomerManagemtPage> createState() => _CustomerManagemtPageState();
}

class _CustomerManagemtPageState extends State<CustomerManagemtPage> {
  final CustomerRepository _repository = CustomerRepository();
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchCustomers();
    });
  }

  Future<void> _fetchCustomers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final data = await _repository.getCustomers();
      if (mounted) {
        setState(() {
          _customers = data;
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
    final TextEditingController nameController = TextEditingController(text: isEdit ? data['customer_name'] : '');
    final TextEditingController phoneController = TextEditingController(text: isEdit ? data['customer_phone_number'] : '');
    final TextEditingController addressController = TextEditingController(text: isEdit ? (data['customer_address'] ?? '') : '');

    bool isSaving = false;

    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? "Edit pelanggan" : "Tambah Pelanggan Baru"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Nama Pelanggan", border: OutlineInputBorder()),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: "No. Telepon / WhatsApp", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: addressController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: "Alamat (Opsional)", border: OutlineInputBorder()),
                  textCapitalization: TextCapitalization.sentences,
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
                if (nameController.text.trim().isEmpty || phoneController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nama dan No. Telepon wajib diisi!")));
                  return;
                }

                setDialogState(() => isSaving = true);
                try {
                  if (isEdit) {
                    await _repository.updateCustomer(data['customer_id'], nameController.text.trim(), phoneController.text.trim(), addressController.text.trim());
                  } else {
                    await _repository.addCustomer(nameController.text.trim(), phoneController.text.trim(), addressController.text.trim());
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                    _fetchCustomers();
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
        title: const Text("Manajemen Pelanggan"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Data",
            onPressed: _fetchCustomers,
          ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _fetchCustomers, 
            child: ListView(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
              children: [
                _customers.isEmpty
                  ? const Center(child: Text("Belum ada data pelanggan"))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraints.maxWidth),
                            child: DataTable(
                              columnSpacing: 20,
                              columns: const [
                                DataColumn(label: Text('Nama', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('No. Telepon', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Alamat', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold))),
                              ], 
                              rows: _customers.asMap().entries.map((entry) {
                                final item = entry.value;
                                return DataRow(
                                  color: WidgetStateProperty.all(entry.key.isOdd ? Colors.grey.shade50 : Colors.white),
                                  cells: [
                                    DataCell(Text(item['customer_name'])),
                                    DataCell(Text(item['customer_phone_number'])),
                                    DataCell(
                                      SizedBox(
                                        width: 300,
                                        child: Text(
                                          item['customer_address'] ?? '-',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        )
                                      )
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
          label: const Text("Tambah Pelanggan"),
        ),
    );
  }
}