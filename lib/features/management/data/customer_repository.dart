import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getCustomers() async {
    try {
      final data = await _supabase
        .from('customers')
        .select()
        .order('customer_name', ascending: true);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception('Gagal mengambil data pelanggan: $e');
    }
  }

  Future<void> addCustomer(String name, String phone, String? address) async {
    try {
      await _supabase.from('customers').insert({
        'customer_name': name,
        'customer_phone_number': phone,
        'customer_address': address?.isEmpty == true ? null : address,
      });
    } catch (e) {
      throw Exception('Gagal menambahkan pelanggan: $e');
    }
  }

  Future<void> updateCustomer(int id, String name, String phone, String? address) async {
    try {
      await _supabase.from('customers').update({
        'customer_name': name,
        'customer_phone_number': phone,
        'customer_address': address?.isEmpty == true ? null : address,
      }).eq('customer_id', id);
    } catch (e) {
      throw Exception('Gagal memperbarui pelanggan: $e');
    }
  }
}