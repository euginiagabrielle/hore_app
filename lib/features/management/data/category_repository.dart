import 'package:supabase_flutter/supabase_flutter.dart';

class CategoryRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final data = await _supabase
        .from('categories')
        .select()
        .order('category_name', ascending: true);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception('Gagal mengambil data kategori: $e');
    }
  }

  Future<void> addCategory(String categoryName) async {
    try {
      await _supabase.from('categories').insert({
        'category_name': categoryName,
      });
    } catch (e) {
      throw Exception('Gagal menambahkan kategori: $e');
    }
  }

  Future<void> updateCategory(int categoryId, String categoryName) async {
    try {
      await _supabase.from('categories').update({
        'category_name': categoryName,
      }).eq('categories_id', categoryId);
    } catch(e) {
      throw Exception('Gagal memperbarui kategori: $e');
    }
  }
}