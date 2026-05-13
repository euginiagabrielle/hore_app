import 'package:hore_app/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentMethodRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    try {
      final data = await supabase
        .from('payment_methods')
        .select()
        .order('payment_method_name', ascending: true);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception('Gagal mengambil data metode pembayara: $e');
    }
  }

  Future<void> addPaymentMethod(String name) async {
    try {
      await _supabase.from('payment_methods').insert({
        'payment_method_name': name,
      });
    } catch (e) {
      throw Exception('Gagal menambahkan metode pembayaran: $e');
    }
  }

  Future<void> updatePaymentMethod(int id, String name) async {
    try {
      await _supabase.from('payment_methods').update({
        'payment_method_name': name,
      }).eq('payment_method_id', id);
    } catch (e) {
      throw Exception('Gagal memperbarui metode pembayaran: $e');
    }
  }
}