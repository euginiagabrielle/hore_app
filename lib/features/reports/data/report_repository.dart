import 'package:supabase_flutter/supabase_flutter.dart';

class ReportRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getOrdersByDate(DateTime date) async {
    try {
      final String dateString = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

      final data = await _supabase
        .from('orders')
        .select('*, customers(customer_name), payment_methods(payment_method_name)')
        .gte('created_at', '$dateString 00:00:00')
        .lte('created_at', '$dateString 23:59:59')
        .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception('Gagal mengambil riwayat transaksi: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getOrderDetails(int orderId) async {
    try {
      final data = await _supabase
        .from('order_details')
        .select('*, products(product_name)')
        .eq('order_id', orderId);
      
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception('Gagal mengambil detail pesanan: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getActivityLogs({
    required DateTime date,
    required int page,
    required int pageSize,
  }) async {
    try {
      final DateTime startOfDay = DateTime(date.year, date.month, date.day);
      final DateTime endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

      final int from = page * pageSize;
      final int to = from + pageSize - 1;

      final data = await _supabase
          .from('activity_logs')
          .select()
          .gte('created_at', startOfDay.toUtc().toIso8601String())
          .lte('created_at', endOfDay.toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .range(from, to);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception('Gagal mengambil log aktivitas: $e');
    }
  }
}