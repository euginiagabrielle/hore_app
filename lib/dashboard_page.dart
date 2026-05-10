// import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:hore_app/features/employees/presentation/activity_log_page.dart';
import 'package:hore_app/features/transaction/data/sales_order_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:hore_app/main.dart';

import 'features/auth/presentation/change_password_dialog.dart';
import 'features/transaction/data/sync_service.dart';
import 'core/services/hybrid_validation_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // final SyncService _syncService = SyncService();
  bool _isCheckingSecurity = true;
  String _securityStatus = "Menginisialisasi Protokol Keamanan...";

  int _employeeId = 0;
  String _employeeName = "Loading...";
  String _employeeRole = "Unknown";
  bool _isTrusted = false;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
    // _enforceSecurityGate();
    // // run sync when dashboard is just opened
    // _syncService.syncOfflineOrdersToSupabase();
    // // Set radar: if the signal has suddenly change from offline to online -> run sync again
    // Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
    //   if(!results.contains(ConnectivityResult.none)) {
    //     _syncService.syncOfflineOrdersToSupabase();
    //   }
    // });
  }

  Future<void> _initializeDashboard() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) context.go('/');
        return;
      }

      // Get employee data
      setState(() => _securityStatus = "Mengambil Profil Pegawai...");

      final userData = await Supabase.instance.client
        .from('employees')
        .select()
        .eq('auth_user_id', user.id)
        .single();

      _employeeId = userData['employee_id'] ?? 0;
      _employeeName = userData['employee_name'] ?? 'Unknown';
      _employeeRole = userData['employee_role'] ?? 'Unknown';
      _isTrusted = userData['is_trusted'] ?? false;

      SalesOrderService().setEmployee(_employeeId, _employeeName);

      // Location Validation
      setState(() => _securityStatus = "Memeriksa Wi-Fi Toko & Sinyal GPS...");

      final gateKeeper = HybridValidationService();
      bool isValid = await gateKeeper.validateAccess(_employeeId, _employeeName, _employeeRole);

      if (isValid && mounted) {
        setState(() {
          _isCheckingSecurity = false;
        });

        if (_employeeRole == 'sales') {
          SyncService().syncOfflineOrdersToSupabase().then((_) {
            print("Auto-Sync Sales Selesai Dijalankan.");
          }).catchError((e) {
            print("Auto-Sync Error: $e");
          });
        }
      }
    } catch (e) {
      if (mounted) {
        _showAccessDeniedDialog(e.toString());
      }
    }
  }

  void _showAccessDeniedDialog(String reason) {
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.gpp_bad, color: Colors.red, size: 30),
            SizedBox(width: 8),
            Text("Akses Ditolak", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(reason),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) context.go('/login');
            },
            child: const Text("Tutup & Keluar"),
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    // Security check UI
    if (_isCheckingSecurity) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              const Text("Otentikasi & Validasi Lokasi", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_securityStatus, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    final String displayRole = _employeeRole[0].toUpperCase() + _employeeRole.substring(1);

    return Scaffold(
      appBar: AppBar(
        title: Text("Dashboard $displayRole"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(_employeeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              accountEmail: Text(_employeeRole.toUpperCase()),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(_employeeName[0].toUpperCase(), style: const TextStyle(fontSize: 24, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
              ),
              decoration: BoxDecoration(color: Colors.blueAccent),
            ),

            // MENU 1: Manage Product
            ListTile(
              leading: const Icon(Icons.inventory, color: Colors.blue),
              title: const Text('Manajemen Produk',style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                context.push('/products', extra: _employeeRole);
              },
            ),

            // MENU 2: Scan QR
            if (_employeeRole == 'sales' || _employeeRole == 'owner')...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.qr_code_scanner, color: Colors.purple),
                title: const Text('Scan QR Produk', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/scan-qr');
                },
              ),
            ],

            // MENU 3: POS -- NANTI TAMPILAN SALES CUMA BISA BUAT PESANAN BUAT SAMPE KE KASIR, NANTI KASIR YG URUS TRANSAKSI SAMPAI PEMBAYARAN
            if (_employeeRole == 'sales' || _employeeRole == 'cashier' || _employeeRole == 'owner')...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.point_of_sale, color: Colors.green),
                title: const Text('Kasir / Transaksi', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/pos');
                },
              ),
            ],

            // MENU 4: Log Activity
            if (_employeeRole == 'owner')
            const Divider(),
            ListTile(
              leading: const Icon(Icons.history_rounded, color: Colors.indigo),
              title: const Text('Log Aktivitas Pegawai', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ActivityLogPage()),
                );
              },
            ),

            // MENU 4: Manage Employee
            if (_isTrusted || _employeeRole == 'owner') ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.people_alt_rounded, color: Colors.redAccent),
                title: const Text(
                  'Manajemen Pegawai',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/employees');
                },
              ),
            ],

            // MENU 5: Printer Settings
            // if (_employeeRole == 'cashier' || _employeeRole == 'owner')...[
            //   const Divider(),
            //   ListTile(
            //     leading: const Icon(Icons.print, color: Colors.green),
            //     title: const Text('Printer Settings', style: TextStyle(fontWeight: FontWeight.bold)),
            //     onTap: () {
            //       Navigator.push(
            //         context, 
            //         MaterialPageRoute(builder: (context) => const PrinterSettings()),
            //       );
            //     },
            //   ),
            // ],

            Divider(),

            // MENU 6: Change Password
            ListTile(
              leading: const Icon(Icons.lock_reset),
              title: const Text("Ganti Password", style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => const ChangePasswordDialog(),
                );
              },
            ),

            Divider(),

            // MENU 7: Logout
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              onTap: () async {
                await supabase.auth.signOut();
                if (context.mounted) {
                  context.go('/');
                }
              },
            ),
          ],
        ),
      ),

      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.storefront, size: 100, color: Colors.blueAccent),
            const SizedBox(height: 20),
            Text("Selamat Datang, $_employeeName!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text("Anda login sebagai $displayRole", style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            if (_isTrusted)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Chip(label: Text("Trusted Staff", style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
              )
          ],
        ),
      ),
    );
  }
}
