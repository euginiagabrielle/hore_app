import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class PosPage extends StatefulWidget {
  const PosPage({super.key});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _pendingOrders = [];
  bool _isLoading = true;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _fetchPendingOrders();
    _setupSupabaseRealtime();
  }

  void _setupSupabaseRealtime() {
    _realtimeChannel = _supabase.channel('public:orders');
    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all, 
      schema: 'public',
      table: 'orders',
      callback: (payload) {
        if (mounted) {
          _fetchPendingOrders();

          if (payload.eventType == PostgresChangeEvent.insert) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Ada pesanan baru!"),
                backgroundColor: Colors.blueAccent,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      }
    ).subscribe();
  }

  @override
  void dispose() {
    _supabase.removeChannel(_realtimeChannel!);
    super.dispose();
  }

  Future<void> _fetchPendingOrders() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
        .from('orders')
        .select('*, employees(employee_name)')
        .eq('order_status', 'pending')
        .order('created_at', ascending: false);

      setState(() {
        _pendingOrders = data;
        _isLoading = false;
      });

      print("PENDING ORDER: \n$data");
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kasir - Antrean Pesanan"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed:_fetchPendingOrders, 
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Manual",
          )
        ],
      ),
      backgroundColor: Colors.grey[100],
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _pendingOrders.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _pendingOrders.length,
              itemBuilder: (context, index) {
                final order = _pendingOrders[index];
                final String orderId = order['order_id'].toString();
                final String salesName = order['employees']?['employee_name'] ?? 'Tidak diketahui';

                final double total = (order['total_price'] as num).toDouble();
                final String formattedTotal = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(total);

                final DateTime createdAt = DateTime.parse(order['created_at']).toLocal();
                final String timeString = DateFormat('HH:mm').format(createdAt);

                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange[100],
                      radius: 25,
                      child: Text("#$orderId", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    ),
                    title: Text("Total: $formattedTotal", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text("Sales: $salesName"),
                        Text("Waktu: $timeString", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                    trailing: ElevatedButton(
                      onPressed: ()  async {
                        final bool? result = await context.push('/pos-payment', extra: {
                          'orderId': order['order_id'],
                          'totalPrice': total,
                        });

                        if (result == true) {
                          _fetchPendingOrders();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text("Proses"),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text("Belum ada antrean pesanan.", style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const Text("Menunggu pesanan dari Sales", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}