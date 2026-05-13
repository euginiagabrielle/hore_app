import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../management/data/product_repository.dart';
import '../transaction/data/sales_order_service.dart';
import '../../core/utils/price_calculator.dart';

class ProductListPage extends StatefulWidget {
  final String userRole;

  const ProductListPage({super.key, required this.userRole});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final ProductRepository _repository = ProductRepository();
  final SalesOrderService _orderService = SalesOrderService();

  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;

  // Search State
  String _searchQuery = "";
  List<Map<String, dynamic>> _selectedForCompare = [];

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      final data = await _repository.getProducts(isActive: true);
      setState(() {
        _products = data;
        _isLoading = false;
        _selectedForCompare.clear();
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // Show product comparison result
  Future<void> _showCompareDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final productIds = _selectedForCompare.map((p) => p['product_id'] as int).toList();
      final specsData = await _repository.getCompareData(productIds);

      // Data grouping based on specification name
      Map<String, Map<int, String>> groupedSpecs = {};

      for (var row in specsData) {
        final specInfo = row['specifications'];
        if (specInfo == null) continue;

        final specName = specInfo['specification_name']?.toString() ?? 'Spesifikasi tidak diketahui.';
        final dataType = specInfo['data_type']?.toString().toLowerCase() ?? 'text';
        final unit = (specInfo['unit'] != null && specInfo['unit'].toString() != 'null') ? specInfo['unit'].toString() : '';
        final fullSpecName = unit.isNotEmpty ? "$specName ($unit)" : specName;
        final productId = row['product_id'] as int;

        String rawValue =
            (row['value'] != null &&
                row['value'].toString() != 'null' &&
                row['value'].toString().isNotEmpty)
            ? row['value'].toString()
            : '-';
        String finalValue = rawValue;

        if (dataType == 'numeric' && rawValue != '-') {
          finalValue = rawValue
              .replaceAll(',', '#')
              .replaceAll('.', ',')
              .replaceAll('#', '.');
        }

        if (!groupedSpecs.containsKey(fullSpecName)) {
          groupedSpecs[fullSpecName] = {};
        }
        groupedSpecs[fullSpecName]![productId] = finalValue;
      }

      if (mounted) {
        Navigator.pop(context);

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Perbandingan Produk", textAlign: TextAlign.center),
            content: SizedBox(
              width: double.maxFinite,
              child: groupedSpecs.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text("Belum ada spesifikasi yang tersimpan untuk produk-produk ini.", textAlign: TextAlign.center),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          border: TableBorder.all(color: Colors.grey.shade400, width: 1.0),
                          headingRowColor: WidgetStateProperty.all(Colors.blue[100]),
                          dataRowMinHeight: 48.0,
                          dataRowMaxHeight: double.infinity,
                          columns: [
                            const DataColumn(
                              label: Text("Spesifikasi", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            ..._selectedForCompare.map(
                              (p) => DataColumn(label: Text(p['product_name'], style: const TextStyle( fontWeight: FontWeight.bold))),
                            ),
                          ],
                          rows: groupedSpecs.entries.map((entry) {
                            final specName = entry.key;
                            final productValuesMap = entry.value;

                            // Comparison logic
                            final List<String> values = _selectedForCompare.map(
                                  (p) => productValuesMap[p['product_id']] ?? '-'
                                ).toList();
                            final bool isDifferent = values.toSet().length > 1;

                            return DataRow(
                              color: isDifferent ? WidgetStateProperty.all(Colors.orange[50]) : null,
                              cells: [
                                DataCell(
                                  Text(specName, style: TextStyle(fontWeight: isDifferent ? FontWeight.bold : FontWeight.normal)),
                                ),
                                ...values.map((val) => DataCell(Text(val))),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Tutup"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal bandingkan $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Local search filter logic
    final filteredProducts = _products.where((p) {
      final name = p['product_name'].toString().toLowerCase();
      final code = p['product_code'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || code.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Katalog Produk"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchProducts),
        ],
      ),

      // Comparing button
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Compare button
          if (_selectedForCompare.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'btn_clear',
                  onPressed: () => setState(() => _selectedForCompare.clear()),
                  backgroundColor: Colors.grey[600],
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  label: const Text("Batal", style: TextStyle(color: Colors.white)),
                ),

                if (_selectedForCompare.length >= 2) ...[
                  const SizedBox(width: 12),
                  FloatingActionButton.extended(
                    heroTag: 'btn_compare',
                    onPressed: _showCompareDialog,
                    backgroundColor: Colors.orange,
                    icon: const Icon(Icons.compare_arrows, color: Colors.white),
                    label: Text("Bandingkan (${_selectedForCompare.length})", style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ],
            ),
          
          if (_selectedForCompare.isNotEmpty && _orderService.totalItemCount > 0)
            const SizedBox(height: 16),

          if (_orderService.totalItemCount > 0 && (widget.userRole == 'sales' || widget.userRole == 'owner'))
            FloatingActionButton.extended(
              heroTag: 'btn_checkout',
              onPressed: () {
                context.push('/checkout');
                setState(() {}); // Refresh UI jika user kembali dari halaman checkout
              },
              backgroundColor: Colors.green,
              icon: const Icon(Icons.receipt_long, color: Colors.white),
              label: Text(
                "Buat Pesanan (${_orderService.totalItemCount} item)",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
        ],
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Cari nama atau kode barang",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Product list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredProducts.isEmpty
                ? const Center(child: Text("Produk tidak ditemukan."))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      final double originalPrice = (product['product_price'] as num).toDouble();
                      final double finalPrice = PriceCalculator.getFinalPrice(product);
                      final bool isDiscounted = PriceCalculator.hasActiveDiscount(product);
                      // print("$product -- $originalPrice -- $finalPrice -- $isDiscounted");

                      final String imageUrl = product['product_picture_url'] ?? '';
                      final String categoryName = product['categories']?['category_name'] ?? 'Tanpa Kategori';
                      final bool isSelected = _selectedForCompare.any((p) => p['product_id'] == product['product_id']);

                      // Checkbox disable logic
                      bool isDisabled = false;
                      if (_selectedForCompare.isNotEmpty) {
                        final int firstSelectedCategoryId =
                            _selectedForCompare.first['category_id'];

                        if (product['category_id'] != firstSelectedCategoryId) {
                          isDisabled = true;
                        }
                      }

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                        color: isSelected ? Colors.orange[50] : Colors.white,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(8),
                          onTap: () {
                            context.push('/product-detail', extra: product['product_code']);
                          },

                          // Checkbox & Gambar
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: isSelected,
                                activeColor: Colors.orange,
                                onChanged: isDisabled
                                    ? null
                                    : (bool? val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedForCompare.add(product);
                                          } else {
                                            _selectedForCompare.removeWhere((p) => p['product_id'] == product['product_id']);
                                          }
                                        });
                                      },
                              ),
                              Opacity(
                                opacity: isDisabled ? 0.5 : 1.0,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: imageUrl.isNotEmpty
                                      ? Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover)
                                      : Container(width: 50, height: 50, color: Colors.grey[300], child: const Icon(Icons.image_not_supported)),
                                ),
                              ),
                            ],
                          ),

                          title: Text(
                            product['product_name'],
                            style: TextStyle(fontWeight: FontWeight.bold, color: isDisabled ? Colors.grey : Colors.black),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text("Kategori: $categoryName", style: const TextStyle(fontSize: 12)),
                              Text("Stok: ${product['product_stock']}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: product['product_stock'] <= 0 ? Colors.red : Colors.grey.shade800)),
                              const SizedBox(height: 6),

                              // Original Price
                              if (isDiscounted)
                                Text(
                                  NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(originalPrice),
                                  style: const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),

                                // Final Price
                                Text(
                                  NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(finalPrice),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14),
                                ),

                                // Badge Diskon
                                if (isDiscounted) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                                    child: Text(
                                      "Diskon ${product['discounts']['discount_value']}%",
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                                    ),
                                  ),
                                ]
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.userRole == 'sales' || widget.userRole == 'owner')
                                IconButton(
                                  onPressed: () {
                                    if (product['product_stock'] <= 0) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Stok Habis!"), backgroundColor: Colors.red),
                                      );
                                      return;
                                    }

                                    setState(() {
                                      _orderService.addItem(product);
                                    });

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("${product['product_name']} ditambahkan!"),
                                        backgroundColor: Colors.green,
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.add_circle, color: Colors.green, size: 32,),
                                ),
                            ],
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
