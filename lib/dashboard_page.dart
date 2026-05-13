import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:hore_app/main.dart';
import 'package:hore_app/features/transaction/data/sales_order_service.dart';

import 'features/auth/presentation/change_password_dialog.dart';
import 'features/transaction/data/sync_service.dart';
import 'core/services/hybrid_validation_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
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
            debugPrint("Auto-Sync Sales Selesai Dijalankan.");
          }).catchError((e) {
            debugPrint("Auto-Sync Error: $e");
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

    // Akses Logika
    final bool isDesktop = 
        defaultTargetPlatform == TargetPlatform.windows || 
        defaultTargetPlatform == TargetPlatform.macOS || 
        defaultTargetPlatform == TargetPlatform.linux;
    final bool isMobile = !isDesktop;

    final bool isOwnerOrTrusted = _employeeRole == 'owner' || _isTrusted;
    final bool canAccessPos = (_employeeRole == 'cashier' || _employeeRole == 'owner') && isDesktop;
    final bool canScanQr = isMobile;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/logo_hore.png',
              height: 32,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 12),
            const Icon(Icons.storefront, color: Colors.white, size: 32),
            const SizedBox(width: 12),
            const Text("HORE POS", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // MENU PROFIL
          PopupMenuButton<String>(
            tooltip: "Menu Akun",
            offset: const Offset(0, 45),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            icon: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Colors.blueAccent),
            ),
            onSelected: (value) async {
              if (value == 'password') {
                showDialog(context: context, builder: (context) => const ChangePasswordDialog());
              } else if (value == 'logout') {
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) context.go('/');
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_employeeName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                    Text(displayRole, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'password',
                child: Row(children: [Icon(Icons.lock_reset, color: Colors.orange, size: 20), SizedBox(width: 8), Text("Ganti Password")]),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(children: [Icon(Icons.logout, color: Colors.red, size: 20), SizedBox(width: 8), Text("Logout", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER WELCOME
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.blueAccent, Colors.lightBlue.shade400]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5))],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: Text(_employeeName[0].toUpperCase(), style: const TextStyle(fontSize: 28, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Halo, $_employeeName!", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(displayRole, style: const TextStyle(fontSize: 14, color: Colors.white70)),
                              if (_isTrusted) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.greenAccent, borderRadius: BorderRadius.circular(4)),
                                  child: const Text("TRUSTED", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                                )
                              ]
                            ],
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),

              const SizedBox(height: 30),
              const Text("Akses Cepat", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 16),

              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2, // 4 kotak untuk Web/Tablet, 2 untuk HP
                childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.2 : 0.9,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildQuickActionCard(context, "Katalog Produk", Icons.inventory_2_rounded, Colors.blue, '/catalog', extra: _employeeRole),
                  
                  if (canAccessPos)
                    _buildQuickActionCard(context, "Kasir / Transaksi", Icons.point_of_sale_rounded, Colors.green, '/pos'),
                  
                  if (canScanQr)
                    _buildQuickActionCard(context, "Scan QR", Icons.qr_code_scanner_rounded, Colors.purple, '/scan-qr'),
                  
                  if (isOwnerOrTrusted)
                    _buildQuickActionCard(context, "Pusat Manajemen", Icons.admin_panel_settings_rounded, Colors.redAccent, '/management'),
                  
                  if (isOwnerOrTrusted)
                    _buildQuickActionCard(context, "Pusat Laporan", Icons.analytics_rounded, Colors.indigo, '/reports'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // WIDGET MENU
  Widget _buildQuickActionCard(BuildContext context, String title, IconData icon, Color color, String route, {Object? extra}) {
    return InkWell(
      onTap: () => context.push(route, extra: extra),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white, 
                shape: BoxShape.circle, 
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8)]
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, height: 1.2, color: color.withValues(alpha: 0.9)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
