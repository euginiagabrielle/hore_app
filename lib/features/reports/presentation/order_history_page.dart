import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/report_repository.dart';
import '../../../core/utils/error_handler.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  final ReportRepository _repository = ReportRepository();

  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchOrders();
    });
  }

  Future<void> _fetchOrders() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final data = await _repository.getOrdersByDate(_selectedDate);
      if (mounted) {
        setState(() {
          _orders = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorHandler.getMessage(e)), backgroundColor: Colors.red));
      }
    }
  }
  
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate, 
      firstDate: DateTime(2026), 
      lastDate: DateTime.now(),
      helpText: "Pilih Tanggal Transaksi",
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _fetchOrders();
    }
  }

  void _showOrderDetailDialog(Map<String, dynamic> order) {
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    
    final double grandTotal = (order['total_price'] ?? 0).toDouble();

    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _repository.getOrderDetails(order['order_id']),
          builder: (context, snapshot) {
            return AlertDialog(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Detail Pesanan", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("ID Order: #${order['order_id']}", style: const TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : snapshot.hasError
                        ? Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red))
                        : snapshot.data!.isEmpty
                            ? const Text("Tidak ada detail item.")
                            : ListView.separated(
                                shrinkWrap: true,
                                itemCount: snapshot.data!.length,
                                separatorBuilder: (context, index) => const Divider(height: 24),
                                itemBuilder: (context, index) {
                                  final item = snapshot.data![index];
                                  final productName = item['products']?['product_name'] ?? 'Produk Dihapus';
                                  final int qty = item['order_quantity'] ?? 0;
                                  final double price = (item['price'] ?? item['unit_price'] ?? item['product_price'] ?? 0).toDouble();
                                  final double subtotal = (item['subtotal'] ?? item['total_price'] ?? (qty * price)).toDouble();
                                  
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      const SizedBox(height: 4),
                                      Text("$qty x ${currencyFormatter.format(price)}", style: TextStyle(color: Colors.grey.shade700)),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Subtotal: ${currencyFormatter.format(subtotal)}", 
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)
                                      ),
                                      const SizedBox(height: 8),
                                      const Text("TOTAL AKHIR:", style: TextStyle(fontWeight: FontWeight.bold)),
                                      Text(
                                        currencyFormatter.format(grandTotal),
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 18),
                                      ),
                                    ],
                                  );
                                },
                              ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Tutup"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String formattedDate = DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate);
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Riwayat Transaksi"),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_month), onPressed: () => _selectDate(context), tooltip: "Pilih Tanggal"),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchOrders, tooltip: "Refresh Data"),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            alignment: Alignment.centerLeft,
            child: Text("Transaksi Tanggal: $formattedDate", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),

          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _orders.isEmpty
                ? Center(child: Text("Tidak ada transaksi pada tanggal $formattedDate."))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraints.maxWidth),
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
                              columns: const [
                                DataColumn(label: Text('Waktu', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('ID Order', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Pelanggan', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Metode Bayar', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold))),
                              ], 
                              rows: _orders.asMap().entries.map((entry) {
                                final order = entry.value;
                                final time = DateTime.parse(order['created_at']).toLocal();
                                final customerName = order['customers']?['customer_name'] ?? "Umum / Guest";
                                final paymentMethod = order['payment_methods']?['payment_method_name'] ?? '-';

                                return DataRow(
                                  color: WidgetStateProperty.all(entry.key.isOdd ? Colors.grey.shade50 : Colors.white),
                                  cells: [
                                    DataCell(Text(DateFormat('HH:mm').format(time))),
                                    DataCell(Text("#${order['order_id']}", style: const TextStyle(fontWeight: FontWeight.bold))),
                                    DataCell(Text(customerName)),
                                    DataCell(Text(paymentMethod)),
                                    DataCell(Text(currencyFormatter.format(order['total_price'] ?? 0), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                                    DataCell(
                                      ElevatedButton.icon(
                                        onPressed: () => _showOrderDetailDialog(order),
                                        icon: const Icon(Icons.receipt_long, size: 16),
                                        label: const Text("Detail"),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                                      )
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}