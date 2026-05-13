import 'package:flutter/material.dart';
import '../data/payment_method_repository.dart';

class PaymentMethodManagementPage extends StatefulWidget {
  const PaymentMethodManagementPage({super.key});

  @override
  State<PaymentMethodManagementPage> createState() => _PaymentMethodManagementPageState();
}

class _PaymentMethodManagementPageState extends State<PaymentMethodManagementPage> {
  final PaymentMethodRepository _repository = PaymentMethodRepository();

  List<Map<String, dynamic>> _paymentMethods = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchPaymentMethods();
    });
  }

  Future<void> _fetchPaymentMethods() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final data = await _repository.getPaymentMethods();
      if (mounted) {
        setState(() {
          _paymentMethods = data;
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
    final TextEditingController nameController = TextEditingController(text: isEdit ? data['payment_method_name'] : '');
    bool isSaving = false;

    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? "Edit Metode Pembayaran" : "Tambah Metode Pembayaran"),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: "Nama Metode (contoh: Cash)",
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
                    await _repository.updatePaymentMethod(data['payment_method_id'], nameController.text.trim());
                  } else {
                    await _repository.addPaymentMethod(nameController.text.trim());
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                    _fetchPaymentMethods();
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
        title: const Text("Manajemen Metode Pembayaran"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Data",
            onPressed: _fetchPaymentMethods,
          ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _fetchPaymentMethods,
            child: ListView(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
              children: [
                _paymentMethods.isEmpty
                  ? const Center(child: Text("Belum ada data."))
                  : DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
                      columns: const [
                        DataColumn(label: Text('Nama Metode', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: _paymentMethods.asMap().entries.map((entry) {
                        final item = entry.value;
                        return DataRow(
                          color: WidgetStateProperty.all(entry.key.isOdd ? Colors.grey.shade50 : Colors.white),
                          cells: [
                            DataCell(Text(item['payment_method_name'])),
                            DataCell(IconButton(
                              icon: const Icon(Icons.edit, color: Colors.orange, size: 20),
                              onPressed: () => _showFormDialog(data: item),
                            )),
                          ],
                        );
                      }).toList(),  
                  ),
              ],
            ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showFormDialog(),
          icon: const Icon(Icons.add),
          label: const Text("Tambah Metode"),
        ),
    );
  }
}