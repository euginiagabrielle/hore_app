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

  // Send order ke kasir
  Future<void> _submitOrder() async {
    if (_orderService.currentCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Silakan pilih atau daftarkan pelanggan terlebih dahulu!"), backgroundColor: Colors.red),
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
      // Ambil data karyawan
      int? empId = _orderService.currentEmployeeId;
      String empName = _orderService.currentEmployeeName ?? "Unknown";
      
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
          _orderService.setEmployee(empId!, empName);
        } else {
          // Jika ternyata sesi login sudah habis
          throw "Sesi login tidak ditemukan. Silakan logout dan login kembali.";
        }
      }

      // Check the internet connection
      final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());
      final bool isOffline = connectivityResult.contains(ConnectivityResult.none);

      // Save to local database as a draft
      await LocalDbHelper.instance.saveDraftOrder(
        customerId: _orderService.currentCustomerId,
        customerName: _orderService.currentCustomerName,
        customerPhone: _phoneController.text,
        employeeId: empId,
        employeeName: empName,
        totalPrice: _orderService.totalPrice,
        items: _orderService.currentItems,
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
            const SnackBar(content: Text("Pesanan berhasil terkirim ke kasir."), backgroundColor: Colors.green),
          );
        }
        // Simulasi pengiriman online sukses
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Pesanan langsung terkirim ke kasir."), backgroundColor: Colors.green),
          );
        }
      }

      // Clear the display after order is saved
      if (mounted) {
        _orderService.clearOrder();
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

  Future<void> _showAddCustomerDialog() async {
    final TextEditingController newNameCtrl = TextEditingController();
    final TextEditingController newPhoneCtrl = TextEditingController();
    final TextEditingController newAddressCtrl = TextEditingController();
    bool isSaving = false;

    await showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Daftar Member Baru"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: newNameCtrl, decoration: const InputDecoration(labelText: "Nama Lengkap (Wajib)")),
                    const SizedBox(height: 8),
                    TextField(controller: newPhoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Nomor HP (Wajib)")),
                    const SizedBox(height: 8),
                    TextField(controller: newAddressCtrl, decoration: const InputDecoration(labelText: "Alamat (Opsional)")),
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
                    if (newNameCtrl.text.trim().isEmpty || newPhoneCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nama dan No HP wajib diisi!"), backgroundColor: Colors.red));
                      return;
                    }

                    setDialogState(() => isSaving = true);

                    try {
                      // Simpan ke Supabase
                      final response = await Supabase.instance.client.from('customers').insert({
                        'customer_name': newNameCtrl.text.trim(),
                        'customer_phone_number': newPhoneCtrl.text.trim(),
                        'customer_address': newAddressCtrl.text.trim().isEmpty ? "-" : newAddressCtrl.text.trim(),
                      }).select('customer_id, customer_name, customer_phone_number').single();

                      // Otomatis terisi ke layar Checkout
                      setState(() {
                        _nameController.text = response['customer_name'];
                        _phoneController.text = response['customer_phone_number'];
                      });
                      _orderService.setCustomer(response['customer_id'], response['customer_name'], response['customer_phone_number']);

                      if (mounted) {
                        Navigator.pop(context); // Tutup dialog tambah member
                        Navigator.pop(context); // Tutup bottom sheet pencarian member
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Member didaftarkan & dipilih!"), backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal mendaftar: $e"), backgroundColor: Colors.red));
                      setDialogState(() => isSaving = false);
                    }
                  }, 
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  child: isSaving 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text("Simpan"),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _showCustomerSearch() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.white, // Pastikan background bersih
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        // 1. Pindahkan Container tinggi fix ke PALING LUAR
        return Container(
          height: MediaQuery.of(context).size.height * 0.7, // Langsung paksa 70% layar
          padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 2. Header render duluan TANPA menunggu database
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Pilih Member", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    onPressed: _showAddCustomerDialog,
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text("Member Baru"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange, 
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  )
                ],
              ),
              const Divider(),
              
              // 3. FutureBuilder HANYA membungkus list datanya saja!
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: Supabase.instance.client
                      .from('customers')
                      .select('customer_id, customer_name, customer_phone_number')
                      .order('customer_name', ascending: true),
                  builder: (context, snapshot) {
                    
                    // Kondisi 1: Sedang Loading
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.orange));
                    }
                    
                    // Kondisi 2: Jika Supabase Error
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}", textAlign: TextAlign.center));
                    }

                    final customers = snapshot.data ?? [];

                    // Kondisi 3: Jika Data Kosong (Termasuk jika diblokir RLS)
                    if (customers.isEmpty) {
                      return const Center(
                        child: Text(
                          "Belum ada data member.\nAtau RLS Supabase belum dibuka.", 
                          textAlign: TextAlign.center, 
                          style: TextStyle(color: Colors.grey)
                        )
                      );
                    }

                    // Kondisi 4: Data Sukses Ditampilkan
                    return ListView.builder(
                      itemCount: customers.length,
                      itemBuilder: (context, index) {
                        final customer = customers[index];
                        return Card(
                          elevation: 0.5,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.person, color: Colors.white)),
                            title: Text(customer['customer_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(customer['customer_phone_number'] ?? '-'),
                            onTap: () {
                              setState(() {
                                _nameController.text = customer['customer_name'];
                                _phoneController.text = customer['customer_phone_number'] ?? '';
                              });
                              _orderService.setCustomer(customer['customer_id'], customer['customer_name'], customer['customer_phone_number']);
                              Navigator.pop(context); // Tutup pop-up
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }
    );
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
                  
                  // TEXTFIELD NAMA
                  TextField(
                    controller: _nameController,
                    readOnly: true,
                    onTap: _showCustomerSearch,
                    decoration: const InputDecoration(
                      labelText: "Nama Pelanggan (Wajib)",
                      hintText: "Ketuk untuk pilih / tambah member",
                      prefixIcon: Icon(Icons.person),
                      suffixIcon: Icon(Icons.search, color: Colors.orange),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // TEXTFIELD NOMOR HP
                  TextField(
                    controller: _phoneController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: "Nomor HP",
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