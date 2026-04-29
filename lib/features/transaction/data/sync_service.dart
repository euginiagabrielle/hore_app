import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/database/local_db_helper.dart';

class SyncService {
  final _supabase = Supabase.instance.client;

  Future<void> syncOfflineOrdersToSupabase() async {
    // Make sure there is internet
    final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) return;

    // Get all orders from sqlite that have is_synced = 0
    final unsyncedOrders = await LocalDbHelper.instance.getUnsyncedOrders();
    if (unsyncedOrders.isEmpty) return;

    // Looping: send order to supabase one by one
    for (var draftOrder in unsyncedOrders) {
      try {
        final draftOrderId = draftOrder['id'];
        
        final orderResponse = await _supabase.from('orders').insert({
          'employee_id': draftOrder['employee_id'],
          'customer_id': draftOrder['customer_id'],
          'order_date': draftOrder['created_at'],
          'total_price': draftOrder['total_price'],
          'payment_method_id': null,
          'order_status': 'pending',
        }).select('order_id').single();

        final int newOrderId = orderResponse['order_id'];

        final items = await LocalDbHelper.instance.getOrderItems(draftOrderId);

        List<Map<String, dynamic>> orderDetailsToInsert = [];
        for (var item in items) {
          final int qty = item['quantity'];
          final double price = item['price'];
          final double originalPrice = item['original_price'];
          final double discountAmount = item['discount_amount'];

          orderDetailsToInsert.add({
            'order_id': newOrderId,
            'product_id': item['product_id'],
            'order_quantity': qty,
            'unit_price': originalPrice,
            'discount_id': item['discount_id'],
            'discount_amount': discountAmount,
            'order_price': price,
            'order_subtotal': qty * price,
          });
        }

        await _supabase.from('order_details').insert(orderDetailsToInsert);

        await LocalDbHelper.instance.markAsSynced(draftOrderId);
        print("Sinkronisasi sukses untuk Order Draft ID: $draftOrderId");

      } catch (e) {
        print("Gagal sinkronisasi Order Draft ID: $draftOrder['id'] - Error: $e");
        throw Exception(e.toString());
      }
    }
  }
}