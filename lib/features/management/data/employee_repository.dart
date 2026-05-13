import 'package:supabase_flutter/supabase_flutter.dart';

class EmployeeRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getEmployees({required bool isOwner}) async {
    try {
      var query = _supabase
        .from('employee_with_emails')
        .select();
      
      if (!isOwner) {
        query = query.neq('employee_role', 'owner');
      }

      final data = await query.order('nip', ascending: true);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addEmployee({
    required String nip,
    required String name,
    required String role,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'create-employee',
        body: {
          'nip': nip,
          'name': name,
          'role': role,
          'email': email,
          'password': password,
        },
      );

      if (response.status != 200) {
        final errorMsg = response.data['error'] ?? 'Gagal membuat akun pegawai';
        throw Exception(errorMsg);
      }
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  Future<void> updateTrustedStatus(String authUserId, bool newStatus) async {
    try {
      await _supabase
          .from('employees')
          .update({'is_trusted': newStatus})
          .eq('auth_user_id', authUserId);
    } catch (e) {
      throw Exception('Gagal mengubah otoritas pegawai: $e');
    }
  }

  Future<void> updateActiveStatus(String authUserId, bool isActive) async {
    try {
      await _supabase
          .from('employees')
          .update({'is_employee_active': isActive})
          .eq('auth_user_id', authUserId);
    } catch (e) {
      throw Exception('Gagal mengubah status aktif pegawai: $e');
    }
  }
}
