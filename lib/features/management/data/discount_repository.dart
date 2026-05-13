import 'package:supabase_flutter/supabase_flutter.dart';

class DiscountRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getDiscounts() async {
    try {
      final data = await _supabase
        .from('discounts')
        .select()
        .order('discount_id', ascending: true);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception('Gagal mengambil data diskon: $e');
    }
  }

  Future<void> addDiscount(String name, double value, bool isActive) async {
    try {
      await _supabase.from('discounts').insert({
        'discount_name': name,
        'discount_value': value,
        'is_discount_active': isActive
      });
    } catch (e) {
      throw Exception('Gagal menambahkan diskon: $e');
    }
  }

  Future<void> updateDiscount(int id, String name, double value, bool isActive) async {
    try {
      await _supabase.from('discounts').update({
        'discount_name': name,
        'discount_value': value,
        'is_discount_active': isActive,
      }).eq('discount_id', id);
    } catch (e) {
      throw Exception('Gagal memperbarui diskon: $e');
    }
  }
}