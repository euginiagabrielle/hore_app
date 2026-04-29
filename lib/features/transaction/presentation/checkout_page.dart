import 'package:flutter/material.dart';
import 'package:hore_app/features/transaction/data/sync_service.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/sales_order_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/database/local_db_helper.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final SalesOrderService _orderService = SalesOrderService();

  // Customer data input
  final  TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isLoading = false;

  void _refresh() {
    setState(() {});
  }

  Future<void> _submitOrder() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nama pelanggan wajib diisi!"), backgroundColor: Colors.red),
      );
      return;
    }

    if (_orderService.currentItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pesanan masih kosong!"), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Data
      // final orderData = {
      //   'customer_name': _nameController.text.trim(),
      //   'customer_phone': _phoneController.text.trim(),
      //   'total_price': _orderService.totalPrice,
      // };
      // final itemsData = _orderService.currentItems;
      final salesService = SalesOrderService();
      int? empId = salesService.currentEmployeeId;
      String empName = salesService.currentEmployeeName ?? "Unknown";
      
      if(empId == null) {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          // Cari data pegawai berdasarkan akun yang sedang login
          final empData = await Supabase.instance.client
            .from('employees')
            .select('employee_id, employee_name')
            .eq('auth_user_id', user.id)
            .single();
          
          empId = empData['employee_id'];
          empName = empData['employee_name'];
          
          // Simpan ke memori agar transaksi berikutnya tidak perlu loading lagi
          salesService.setEmployee(empId!, empName);
        } else {
          // Jika ternyata sesi login sudah habis
          throw "Sesi login tidak ditemukan. Silakan logout dan login kembali.";
        }
      }

      int? finalCustomerId = salesService.currentCustomerId;
      if (finalCustomerId == 0) {
        finalCustomerId = null; 
      }

      // Check the internet connection
      final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());
      final bool isOffline = connectivityResult.contains(ConnectivityResult.none);

      // Save to local database as a draft
      await LocalDbHelper.instance.saveDraftOrder(
        customerId: finalCustomerId,
        customerName: _nameController.text.trim(),
        employeeId: empId,
        employeeName: empName,
        totalPrice: salesService.totalPrice,
        items: salesService.currentItems,
      );

      if  (isOffline) {
        // Offline condition
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Anda sedang Offline! Pesanan disimpan sebagai draft. Akan dikirim otomatis saat koneksi pulih."),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        // Online condition
        final SyncService syncService = SyncService();
        await syncService.syncOfflineOrdersToSupabase();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Pesanan berhasil terkirim ke kasir."),
              backgroundColor: Colors.green,
            ),
          );
        }
        // Simulasi pengiriman online sukses
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Pesanan langsung terkirim ke kasir."),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      // Clear the display after order is saved
      if (mounted) {
        _orderService.clearOrder();
        salesService.clearOrder();
        context.pop();
      }

    } catch(e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Terjadi kesalahan: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _orderService.currentItems;
    final  double totalPrice = _orderService.totalPrice;
    final String formattedTotal= NumberFormat.currency(
      locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0,
    ).format(totalPrice);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ringkasan Pesanan"),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: items.isEmpty
        ? const Center(child: Text("Belum ada barang dipilih.", style: TextStyle(fontSize: 16)))
        : Column(
          children: [
            // Form data pelanggan
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Informasi Pelanggan", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: "Nama Lengkap",
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: "Nomor HP (opsional)",
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Daftar barang
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final product = item['product'];
                  final int qty = item['quantity'];

                  final double price = (product['product_price'] as num).toDouble();
                  final String formattedPrice = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0,).format(price);

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Padding(
                      padding: const EdgeInsetsGeometry.all(8.0),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadiusGeometry.circular(8),
                            child: product['product_picture_url'] != null && product['product_picture_url'].toString().isNotEmpty
                              ? Image.network(product['product_picture_url'], width: 60, height: 60, fit: BoxFit.cover)
                              : Container(width: 60, height: 60, color: Colors.grey[200], child: const Icon(Icons.image)),
                          ),
                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(product['product_name'], style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                                Text(formattedPrice, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))
                              ],
                            ),
                          ),

                          Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  _orderService.removeItem(product['product_id']);
                                  _refresh();
                                },
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                              ),
                              Text('$qty', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              IconButton(
                                onPressed: () {
                                  if (qty >= product['product_stock']) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mencapai batas maksimal stok!"), backgroundColor: Colors.red));
                                    return;
                                  }
                                  _orderService.addItem(product);
                                  _refresh();
                                },
                                icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                }
              ),
            ),
          ],
        ),

        bottomNavigationBar: items.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 10, offset: const Offset(0, -2))],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Total Tagihan", style: TextStyle(color: Colors.grey)),
                          Text(formattedTotal, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submitOrder, 
                      icon: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send, color: Colors.white),
                      label: Text(_isLoading ? "Memproses..." : "Kirim ke Kasir", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}