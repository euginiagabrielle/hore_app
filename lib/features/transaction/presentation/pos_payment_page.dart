import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:path/path.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
// import 'package:go_router/go_router.dart';

class PosPaymentPage extends StatefulWidget {
  final int orderId;
  final double totalPrice;

  const PosPaymentPage({super.key, required this.orderId, required this.totalPrice});

  @override
  State<PosPaymentPage> createState() => _PosPaymentPageState();
}

class _PosPaymentPageState extends State<PosPaymentPage> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _cashController = TextEditingController();

  Map<String, dynamic>? _orderData;
  List<Map<String, dynamic>> _orderDetails = [];
  bool _isLoading = true;
  bool _isProcessingPay = false;
  double _kembalian= 0.0;
  List<Map<String, dynamic>> _paymentMethods = [];
  int? _selectedPaymentMethodId;
  String _selectedPaymentMethodName = '';

  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
    _fetchPaymentMethods();

    // To count kembalian automatically when the cashier input the cash nominal
    _cashController.addListener(() {
      final String text = _cashController.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (text.isNotEmpty) {
        final double cash = double.parse(text);
        setState(() {
          _kembalian = cash - widget.totalPrice;
        });
      } else {
        setState(() => _kembalian = 0.0);
      }
    });
  }

  final NumberFormat currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  Future<void> _fetchOrderDetails() async {
    try {
      final data = await _supabase
        .from('orders')
        .select('''
          *,
          employees (employee_name),
          customers (customer_name),
          order_details (
            *,
            products (product_name, product_stock)
          )
        ''')
        .eq('order_id', widget.orderId)
        .single();
      
      setState(() {
        _orderData = data;
        _orderDetails = List<Map<String, dynamic>>.from(data['order_details']);
        _isLoading = false;
      });

      print("ORDER DATA: \n$data");
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text("Error: $e")));
      setState(() => _isLoading = false);
      print("ERROR FETCH ORDER: $e");
    }
  }

  Future<void> _fetchPaymentMethods() async {
    try {
      final data = await _supabase.from('payment_methods').select();
      setState(() {
        _paymentMethods = data;
        if (data.isNotEmpty) {
          _selectedPaymentMethodId = data[0]['payment_method_id'];
          _selectedPaymentMethodName = data[0]['payment_method_name'];
        }
      });
    } catch (e) {
      print("Gagal memuat metode pembayaran: $e");
    }
  }

  Future<void> _processPaymentAndPrint() async {
    final double cash = double.tryParse(_cashController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;

    final isCashPayment = _selectedPaymentMethodName.toLowerCase().contains('cash');
    if (isCashPayment && cash < widget.totalPrice) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Uang tunai kurang dari total tagihan!"), backgroundColor: Colors.red));
      return;
    }

    if (_selectedPaymentMethodId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pilih metode pembayaran terlebih dahulu!"), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isProcessingPay = true);

    try {
      // await _supabase.from('orders').update({
      //   'payment_method_id': _selectedPaymentMethodId,
      //   'order_status': 'paid'
      // }).eq('order_id', widget.orderId);

      await _supabase.rpc('process_payment', params: {
        'p_order_id': widget.orderId,
        'p_payment_method_id': _selectedPaymentMethodId,
      });

      // Print thermal receipt
      await _printReceipt(cash);

      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text("Pembayaran Berhasil & Struk Dicetak!"), backgroundColor: Colors.green));
        Navigator.pop(this.context, true);
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text("Gagal memproses $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessingPay = false);
    }
  }

  // Receipt design using thermal paper 80mm
  Future<void> _printReceipt(double cashAmount) async {
    final doc = pw.Document();

    double totalBruto = 0;
    double totalHemat = 0;

    for (var item in _orderDetails) {
      final double unitPrice = (item['unit_price'] as num).toDouble();
      final double disc = (item['discount_amount'] as num?)?.toDouble() ?? 0;
      final int qty = item['order_quantity'];

      totalBruto += (unitPrice * qty);
      totalHemat += (disc * qty);
    }

    final String formattedBruto = currencyFormatter.format(totalBruto);
    final String formattedHemat = currencyFormatter.format(totalHemat);
    final String formattedTotal = currencyFormatter.format(widget.totalPrice);

    final String formattedCash = currencyFormatter.format(cashAmount);
    final String formattedKembalian = currencyFormatter.format(_kembalian > 0 ? _kembalian : 0);
    final String dateStr = DateFormat('dd MMM yyyy HH:mm').format(DateTime.now());

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          105 * PdfPageFormat.mm, //width
          // 150 * PdfPageFormat.mm, 
          double.infinity, //length
        ),
        margin: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER
              pw.Center(child: pw.Text("HORE ELECTRONIC", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 2),
              pw.Center(child: pw.Text("Jl. Pahlawan No.123, Surabaya", style: const pw.TextStyle(fontSize: 10))),
              pw.SizedBox(height: 6),
              pw.Divider(),

              // INFO TRANSAKSI
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Nota", style: const pw.TextStyle(fontSize: 9)),
                  pw.Text("#${widget.orderId}", style: const pw.TextStyle(fontSize: 9)),
                ]
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Tanggal", style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(dateStr, style: const pw.TextStyle(fontSize: 9)),
                ]
              ),
              pw.SizedBox(height: 4),
              pw.Divider(),

              // DAFTAR BARANG
              pw.SizedBox(height: 4),
              ..._orderDetails.map((item) {
                final String name = item['products']['product_name'];
                final int qty = item['order_quantity'];
                final double price = (item['order_price'] as num).toDouble();
                final double subtotal = (item['order_subtotal'] as num).toDouble();
                final double discount = (item['discount_amount'] as num?)?.toDouble() ?? 0;
                final double lineDiscount = discount * qty;

                // return pw.Padding(
                //   padding: const pw.EdgeInsets.only(bottom: 6),
                //   child: pw.Row(
                //     mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                //     children: [
                //       pw.Expanded(child: pw.Text("$name x$qty", style: const pw.TextStyle(fontSize: 10))),
                //       pw.Text(subtotal, style: const pw.TextStyle(fontSize: 10)),
                //     ],
                //   )
                // );

                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(name, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text("   $qty x ${currencyFormatter.format(price)}", style: const pw.TextStyle(fontSize: 9)),
                          pw.Text(currencyFormatter.format(subtotal), style: const pw.TextStyle(fontSize: 9)),
                        ],
                      ),

                      if (discount > 0)
                        pw.Container(
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(
                            "(Hemat: -${currencyFormatter.format(lineDiscount)})",
                            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)
                          ),
                        ),
                    ],
                  ),
                );
              }),
              pw.SizedBox(height: 4),
              pw.Divider(),

              // TOTAL & PEMBAYARAN
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Total", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.Text(formattedBruto, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ]
              ),
              if (totalHemat > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Total Hemat", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.Text(formattedHemat, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700))
                  ]
                ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Total Akhir", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text(formattedTotal, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))
                ]
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, 
                children: [
                  pw.Text("Pembayaran", style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(_selectedPaymentMethodName, style: const pw.TextStyle(fontSize: 9)),
                ]
              ),

              if (_selectedPaymentMethodName == 'Cash') ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Tunai", style: pw.TextStyle(fontSize: 9)), 
                    pw.Text(formattedCash, style: const pw.TextStyle(fontSize: 9)),
                  ]
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Kembalian", style: const pw.TextStyle(fontSize: 9)), 
                    pw.Text(formattedKembalian, style: const pw.TextStyle(fontSize: 9)),
                  ]
                ),
              ],
              pw.SizedBox(height: 8),
              pw.Divider(),

              // FOOTER
              pw.SizedBox(height: 8),
              pw.Center(child: pw.Text("Terima Kasih Atas Kunjungan Anda", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
              pw.Center(child: pw.Text("Barang yang sudah dibeli tidak dapat ditukar atau dikembalikan.", style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
              pw.SizedBox(height: 20),
            ],
          );
        },
      ),
    );

    // Direct Print
    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Struk_Nota_${widget.orderId}',
      );
      // final prefs = await SharedPreferences.getInstance();
      // final printerUrl = prefs.getString('default_printer_url');

      // if (printerUrl != null && printerUrl.isNotEmpty) {
      //   // Jika printer sdh disetting, cetak
      //   final selectedPrinter = Printer(url: printerUrl);
      //   // await Printing.directPrintPdf(
      //   //   printer: selectedPrinter, 
      //   //   onLayout: (PdfPageFormat format) async => doc.save(),
      //   //   name: 'Struk_Nota_${widget.orderId}',
      //   // );
      //   await Printing.layoutPdf(
      //     onLayout: (PdfPageFormat format) async => doc.save(),
      //     name: 'Struk_Nota_${widget.orderId}',
      //   );
      // } else {
      //   // Fallback jika blm setting printer, munculkan popup
      //   await Printing.layoutPdf(
      //     onLayout: (PdfPageFormat format) async => doc.save(),
      //     name: 'Struk_Nota_${widget.orderId}',
      //   );
      // }
    } catch (e) {
      print("Gagal cetak struk: $e");
      // Fallback jika print gagal
      // await Printing.layoutPdf(
      //   onLayout: (PdfPageFormat format) async => doc.save(),
      //   name: 'Struk_Nota_${widget.orderId},'
      // );
    }
  }

  Future<void> _cancelOrder() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Batalkan & Hapus Pesanan?"),
        content: const Text("Pesanan ini akan dihapus permanen dari sistem.  Lanjutkan?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("TIDAK")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("YA, HAPUS", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (!confirm) return;
    setState(() => _isProcessingPay = true);

    try {
      final checkOrder = await _supabase
        .from('orders')
        .select('order_status')
        .eq('order_id', widget.orderId)
        .single();

      if (checkOrder['order_status'] != 'pending') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Gagal! Pesanan ini sudah diproses/dibayar."), backgroundColor: Colors.red)
          );
        }
        return;
      }

      await _supabase
        .from('order_details')
        .delete()
        .eq('order_id', widget.orderId);

      await _supabase
        .from('orders')
        .delete()
        .eq('order_id', widget.orderId)
        .eq('order_status', 'pending');
        
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pesanan berhasil dihapus permanen"), backgroundColor: Colors.green)
        );
        Navigator.pop(context, true); // Kembali ke halaman Dashboard Kasir
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal menghapus pesanan: $e"), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingPay = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String formattedTotal= NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(widget.totalPrice);

    return Scaffold(
      appBar: AppBar(
        title: Text("Pembayaran Nota #${widget.orderId}"), 
        backgroundColor: Colors.green, 
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoading && _orderData?['order_status'] == 'pending')
            IconButton(
              onPressed: _isProcessingPay ? null : _cancelOrder, 
              tooltip: "Batalkan & Hapus Pesanan",
              icon: const Icon(Icons.delete_outline, color: Colors.white,)
            ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Receipt
            Expanded(
              flex: 3,
              child: Container(
                color: Colors.white,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _orderDetails.length,
                  itemBuilder: (context, index) {
                    // final item = _orderDetails[index];
                    // final String price = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(item['order_price']);
                    // return ListTile(
                    //   title: Text(item['products']['product_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    //   subtitle: Text("${item['order_quantity']} x $price"),
                    //   trailing: Text(NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(item['order_subtotal'])),
                    // );
                    final item = _orderDetails[index];
                    final product = item['products'];
                    final double unitPrice = (item['unit_price'] as num).toDouble();
                    final discountAmount = (item['discount_amount'] as num?)?.toDouble() ?? 0;
                    final double finalPrice = (item['order_price'] as num).toDouble();
                    final int qty = item['order_quantity'];
                    final double subtotal = (item['order_subtotal'] as num).toDouble();

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        product['product_name'],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Quantity: $qty x ${currencyFormatter.format(finalPrice)}"),
                          if (discountAmount > 0) ...[
                            Row(
                              children: [
                                Text(
                                  currencyFormatter.format(unitPrice),
                                  style: const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Diskon ${currencyFormatter.format(discountAmount)}",
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      trailing: Text(
                        currencyFormatter.format(subtotal),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Payment Input
            Expanded(
              flex: 2,
              child: Container(
                color: Colors.grey[100],
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Total Tagihan", style: TextStyle(fontSize: 16, color: Colors.grey)),
                    Text(formattedTotal, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green)),
                    const SizedBox(height: 24),

                    // Choose payment method
                    DropdownButtonFormField<int>(
                      initialValue: _selectedPaymentMethodId,
                      decoration: const InputDecoration(labelText: "Metode Pembayaran", border: OutlineInputBorder()),
                      items: _paymentMethods.map((method) {
                        return DropdownMenuItem<int>(
                          value: method['payment_method_id'],
                          child: Text(method['payment_method_name'])
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _selectedPaymentMethodId = newValue;
                          _selectedPaymentMethodName = _paymentMethods.firstWhere(
                            (m) => m['payment_method_id'] == newValue
                          )['payment_method_name'];
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    if (_selectedPaymentMethodName == 'Cash') ...[
                      TextField(
                        controller: _cashController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          labelText: "Uang Diterima (Rp)",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.payment),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: _kembalian < 0 ? Colors.red[50] : Colors.green[50], borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_kembalian < 0 ? "KURANG:" : "KEMBALIAN:", style: TextStyle(fontWeight: FontWeight.bold, color: _kembalian < 0 ? Colors.red : Colors.green)),
                            Text(
                              currencyFormatter.format(_kembalian.abs()),
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _kembalian < 0 ? Colors.red : Colors.green),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const Spacer(),

                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: _isProcessingPay ? null : _processPaymentAndPrint,
                        icon: _isProcessingPay
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Icon(Icons.print, size: 28, color: Colors.white),
                        label: Text(_isProcessingPay ? "MEMPROSES..." : "BAYAR & CETAK STRUK", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.circular(12))),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
    );
  }
}