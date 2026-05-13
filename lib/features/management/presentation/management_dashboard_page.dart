import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ManagementDashboardPage extends StatelessWidget {
  const ManagementDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pusat Manajemen Data"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Master Produk"),
            _buildGrid(context, [
              _buildMenuCard(context, title: "Data Produk", icon: Icons.inventory_2, color: Colors.blue, route: '/manage-product'),
              _buildMenuCard(context, title: "Kategori", icon: Icons.category_rounded, color: Colors.orange, route: '/manage-category'),
              _buildMenuCard(context, title: "Spesifikasi", icon: Icons.list_alt, color: Colors.purple, route: '/manage-specification'),
            ]),
            
            const SizedBox(height: 24),

            _buildSectionTitle("Master Pegawai"),
            _buildGrid(context, [
              _buildMenuCard(context, title: "Data Pegawai", icon: Icons.people, color: Colors.indigo, route: '/employees'),
            ]),
            
            const SizedBox(height: 24),

            _buildSectionTitle("Master Transaksi"),
            _buildGrid(context, [
              _buildMenuCard(context, title: "Metode Bayar", icon: Icons.payments_rounded, color: Colors.green, route: '/manage-payment-method'),
              _buildMenuCard(context, title: "Diskon Promo", icon: Icons.percent, color: Colors.redAccent, route: '/manage-discount'),
              _buildMenuCard(context, title: "Pelanggan", icon: Icons.group, color: Colors.teal, route: '/manage-customer'),
            ]),
            
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // Widget khusus untuk Judul Section
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  // Widget khusus untuk Grid Responsif
  Widget _buildGrid(BuildContext context, List<Widget> children) {
    // Mengecek lebar layar untuk menentukan 3 atau 4 card per baris
    final double screenWidth = MediaQuery.of(context).size.width;
    final int columns = screenWidth > 600 ? 4 : 3;

    return GridView.count(
      crossAxisCount: columns,
      crossAxisSpacing: 12, // Spasi sedikit dikurangi agar tidak terlalu jauh
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // Memberikan rasio sedikit lebih tinggi agar muat untuk teks 2 baris (misal 0.9)
      childAspectRatio: 0.9, 
      children: children,
    );
  }

  // Widget Kartu Menu
  Widget _buildMenuCard(BuildContext context, {required String title, required IconData icon, required Color color, required String route}) {
    return InkWell(
      onTap: () => _handleNavigation(context, route),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.0),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color), // Ukuran icon dikecilkan dari 40 menjadi 32
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2, // Maksimal teks 2 baris
                overflow: TextOverflow.ellipsis, // Jika kepanjangan jadi titik-titik (...)
                style: TextStyle(
                  fontSize: 12, // Ukuran font dikecilkan dari 14 ke 12
                  fontWeight: FontWeight.bold, 
                  color: color.withValues(alpha: 0.9),
                  height: 1.2, // Jarak antar baris teks agar lebih rapat
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Sistem Pengaman Navigasi
  void _handleNavigation(BuildContext context, String route) {
    final List<String> readyRoutes = [
      '/manage-product', 
      '/manage-category', 
      '/employees', 
      '/manage-payment-method',
      '/manage-discount',
      '/manage-specification',
      '/manage-customer',
    ];

    if (readyRoutes.contains(route)) {
      context.push(route);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Fitur $route sedang dalam tahap pengembangan (Coming Soon)"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}