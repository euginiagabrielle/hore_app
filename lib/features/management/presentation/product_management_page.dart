import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../data/product_repository.dart';
import '../../../core/utils/price_calculator.dart';
import '../../../core/utils/error_handler.dart';

class ProductManagementPage extends StatefulWidget {
  const ProductManagementPage({super.key});

  @override
  State<ProductManagementPage> createState() => _ProductManagementPageState();
}

class _ProductManagementPageState extends State<ProductManagementPage> {
  final ProductRepository _repo = ProductRepository();
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  bool _showActive = true;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchProducts();
    });
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      final data = await _repo.getProducts(isActive: _showActive);
      setState(() {
        _products = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorHandler.getMessage(e))));
    }
  }

  // Disable Product
  Future<void> _confirmDisable(int productId, String productName) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nonaktifkan Produk?"),
        content: Text("Yakin ingin menonaktifkan '$productName'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Nonaktifkan", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _repo.disableProduct(productId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produk dinonaktifkan')));
          _fetchProducts();
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  // Enable Product
  Future<void> _confirmEnable(int productId, String productName) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Aktifkan Produk?"),
        content: Text("Yakin ingin mengaktifkan '$productName' ke daftar produk?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Aktifkan", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _repo.enableProduct(productId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produk diaktifkan!')));
          _fetchProducts();
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  void _showQrCode(Map<String, dynamic> product) {
    final String qrUrl = product['product_qr_code'] ?? '';
    final String productName = product['product_name'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(productName, textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            qrUrl.isNotEmpty
                ? Image.network(qrUrl, width: 200, height: 200, fit: BoxFit.cover)
                : const Icon(Icons.qr_code_scanner, size: 100, color: Colors.grey),
            const SizedBox(height: 16),
            const Text("Scan QR ini untuk melihat detail", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Tutup")),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _printLabel(product);
            },
            icon: const Icon(Icons.print, color: Colors.white, size: 18),
            label: const Text("Cetak Label", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
          ),
        ],
      ),
    );
  }

  Future<void> _printLabel(Map<String, dynamic> product) async {
    final doc = pw.Document();
    final double originalPrice = (product['product_price'] as num).toDouble();
    final double finalPrice = PriceCalculator.getFinalPrice(product);
    final bool isDiscounted = PriceCalculator.hasActiveDiscount(product);
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) {
          return pw.Container(
            width: double.infinity,
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1)),
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  decoration: const pw.BoxDecoration(color: PdfColors.black),
                  child: pw.Center(child: pw.Text("HORE ELECTRONIC", style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold, letterSpacing: 2))),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Column(
                    children: [
                      pw.Text(product['product_name'].toString().toUpperCase(), textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), maxLines: 3),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text("KODE BARANG:", style: const pw.TextStyle(fontSize: 8)),
                                pw.Text(product['product_code'], style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                pw.SizedBox(height: 10),
                                if (isDiscounted) ...[
                                  pw.Text(currencyFormatter.format(originalPrice), style: pw.TextStyle(fontSize: 16, color: PdfColors.grey600, decoration: pw.TextDecoration.lineThrough)),
                                  pw.SizedBox(height: 2),
                                  pw.Text(currencyFormatter.format(finalPrice), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                                ] else ...[
                                  pw.Text(currencyFormatter.format(originalPrice), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                                ],
                              ],
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.BarcodeWidget(data: product['product_code'], barcode: pw.Barcode.qrCode(), width: 80, height: 80),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save(), name: 'Label_${product['product_code']}');
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _products.where((p) {
      final name = p['product_name'].toString().toLowerCase();
      final code = p['product_code'].toString().toLowerCase();
      return name.contains(_searchQuery) || code.contains(_searchQuery);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_showActive ? "Manajemen Produk (Aktif)" : "Manajemen Produk (Nonaktif)"),
        actions: [
          PopupMenuButton<bool>(
            icon: const Icon(Icons.filter_list),
            tooltip: "Filter Produk",
            onSelected: (bool isShowActive) {
              setState(() => _showActive = isShowActive);
              _fetchProducts();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: true, child: Text("Tampilkan Produk Aktif")),
              PopupMenuItem(value: false, child: Text("Tampilkan Produk Nonaktif")),
            ],
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchProducts),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Cari nama atau kode barang...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true, fillColor: Colors.white,
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchProducts,
                    child: ListView(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 100),
                      children: [
                        filteredProducts.isEmpty
                            ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text("Produk tidak ditemukan.")))
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
                                          DataColumn(label: Text('Foto', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Kode', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Nama Produk', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Kategori', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Stok', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Harga Dasar', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold))),
                                        ],
                                        rows: filteredProducts.asMap().entries.map((entry) {
                                          final item = entry.value;
                                          final catName = item['categories']?['category_name'] ?? '-';
                                          final imgUrl = item['product_picture_url'] ?? '';
                                          
                                          return DataRow(
                                            color: WidgetStateProperty.all(entry.key.isOdd ? Colors.grey.shade50 : Colors.white),
                                            cells: [
                                              DataCell(
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(6),
                                                  child: imgUrl.isNotEmpty 
                                                    ? Image.network(imgUrl, width: 40, height: 40, fit: BoxFit.cover)
                                                    : Container(width: 40, height: 40, color: Colors.grey.shade300, child: const Icon(Icons.image, size: 20)),
                                                )
                                              ),
                                              DataCell(Text(item['product_code'])),
                                              DataCell(Text(item['product_name'])),
                                              DataCell(Text(catName, style: TextStyle(color: Colors.blue.shade800))),
                                              DataCell(Text(item['product_stock'].toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                                              DataCell(Text(NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(item['product_price']))),
                                              DataCell(
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(Icons.visibility, color: Colors.teal),
                                                      tooltip: "Lihat Detail",
                                                      onPressed: () {
                                                        context.push('/product-detail', extra: item['product_code']);
                                                      },
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.qr_code, color: Colors.blueAccent),
                                                      tooltip: "Cetak Label QR",
                                                      onPressed: () => _showQrCode(item),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.edit, color: Colors.orange),
                                                      tooltip: "Edit Produk",
                                                      onPressed: () async {
                                                        final result = await context.push('/edit-product', extra: item);
                                                        if (result == true) _fetchProducts();
                                                      },
                                                    ),
                                                    _showActive
                                                      ? IconButton(icon: const Icon(Icons.delete, color: Colors.red), tooltip: "Nonaktifkan", onPressed: () => _confirmDisable(item['product_id'], item['product_name']))
                                                      : IconButton(icon: const Icon(Icons.restore, color: Colors.green), tooltip: "Aktifkan", onPressed: () => _confirmEnable(item['product_id'], item['product_name'])),
                                                  ],
                                                )
                                              ),
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/add-product');
          _fetchProducts();
        },
        icon: const Icon(Icons.add),
        label: const Text("Tambah Produk"),
      ),
    );
  }
}