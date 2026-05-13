import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../management/data/product_repository.dart';
import '../../core/utils/price_calculator.dart';
import '../../../core/utils/error_handler.dart';

class ProductDetailPage extends StatefulWidget {
  final String productCode;

  const ProductDetailPage({super.key, required this.productCode});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final ProductRepository _repo = ProductRepository();
  Map<String, dynamic>? _product;
  List<dynamic> _specs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    try {
      final data = await _repo.getProductDetailByCode(widget.productCode);
      if (mounted) {
        setState(() {
          if (data != null) {
            _product = data['product'];
            _specs = data['specs'];
          }
        _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorHandler.getMessage(e))));
      }
    }
  }

  String _formatSpecValue(String rawValue, String dataType) {
    if (rawValue.isEmpty || rawValue == 'null') return '-';

    if (dataType == 'numeric') {
      return rawValue.replaceAll(',', '#').replaceAll('.', ',').replaceAll('#', '.');
    }

    return rawValue;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_product == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Detail Produk")),
        body: const Center(child: Text("Produk tidak ditemukan.")),
      );
    }
    
    // final double price = (_product!['product_price'] as num).toDouble();
    // final String formattedPrice = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(price);
    final String imageUrl = _product!['product_picture_url'] ?? '';
    final String categoryName = _product!['categories']?['category_name'] ?? 'Tanpa Kategori';
    final double originalPrice = (_product!['product_price'] as num).toDouble();
    final double finalPrice = PriceCalculator.getFinalPrice(_product!);
    final bool isDiscounted = PriceCalculator.hasActiveDiscount(_product!);

    return Scaffold(
      appBar: AppBar(title: Text(_product!['product_name'])),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadiusGeometry.circular(12),
                child: Image.network(imageUrl, height: 250, fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 250,
                      width: double.infinity,
                      color: Colors.grey.shade200,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.wifi_off, size: 50, color: Colors.grey),
                          SizedBox(height: 8),
                          Text("Gambar tidak dapat dimuat", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                height: 200,
                color: Colors.grey[200],
                child: const Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
              ),
            
            const SizedBox(height: 16),

            // Product information
            Text(_product!['product_name'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // Text(formattedPrice, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
            if (isDiscounted)
              Text(
                NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(originalPrice),
                style: const TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: Colors.red,
                  fontSize: 16,
                ),
              ),

            Text(
              NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(finalPrice),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
                fontSize: 28,
              ),
            ),

            if (isDiscounted) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  "Diskon ${_product!['discounts']['discount_value']}%",
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              )
            ],

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(label: Text("Kategori: $categoryName")),
                Chip(label: Text("Stok: ${_product!['product_stock']}", style: const TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),

            const Divider(height: 32, thickness: 1),
            const Text("Spesifikasi", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Specification table
            _specs.isEmpty
              ? const Text("Belum ada spesifikasi untuk produk ini.")
              : Table(
                border: TableBorder.all(color: Colors.grey.shade300),
                columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(1.5)},
                children: _specs.map((specRow) {
                  final specInfo = specRow['specifications'];
                  final specName = specInfo['specification_name'];
                  final unit = specInfo['unit'] != null && specInfo['unit'].toString() != 'null' ? "${specInfo['unit']}" : "";
                  final dataType = specInfo['data_type']?.toString().toLowerCase() ?? 'text';
                  final value = _formatSpecValue(specRow['value'].toString(), dataType);

                  return TableRow(
                    decoration: BoxDecoration(color: _specs.indexOf(specRow) % 2 == 0 ? Colors.blue[50] : Colors.white),
                    children: [
                      Padding(padding: const EdgeInsets.all(12), child: Text(specName, style: const TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: const EdgeInsets.all(12), child: Text("$value $unit")),
                    ],
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}