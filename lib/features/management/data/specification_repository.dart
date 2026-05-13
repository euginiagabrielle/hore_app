import 'package:supabase_flutter/supabase_flutter.dart';

class SpecificationRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getSpecifications() async {
    try {
      final data = await _supabase
        .from('specifications')
        .select('*, categories(category_name)')
        .order('categories_id', ascending: true);
      return List<Map<String, dynamic>>.from(data);
    } catch(e) {
      throw Exception('Gagal mengambil data spesifikasi: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCategoriesForDropdown() async {
    try {
      final data = await _supabase
        .from('categories')
        .select('categories_id, category_name')
        .order('category_name', ascending: true);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception('Gagal mengambil daftar kategori: $e');
    }
  }

  Future<void> addSpecification(int categoryId, String name, String dataType, String? unit) async {
    try {
      await _supabase.from('specifications').insert({
        'categories_id': categoryId,
        'specification_name': name,
        'data_type': dataType,
        'unit': unit?.isEmpty == true ? null : unit,
      });
    } catch (e) {
      throw Exception('Gagal menambahkan spesifikasi: $e');
    }
  }

  Future<void> updateSpecifiction(int id, int categoryId, String name, String dataType, String? unit) async {
    try {
      await _supabase.from('specifications').update({
        'categories_id': categoryId,
        'specification_name': name,
        'data_type': dataType,
        'unit': unit?.isEmpty == true ? null : unit,
      }).eq('specification_id', id);
    } catch (e) {
      throw Exception('Gagal memperbarui spesifikasi: $e');
    }
  }
}