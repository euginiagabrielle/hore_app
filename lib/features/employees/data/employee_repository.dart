// import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hore_app/main.dart';

class EmployeeRepository {
  Future<List<Map<String, dynamic>>> getEmployees() async {
    try {
      final data = await supabase
          .from('employees')
          .select()
          .order('nip', ascending: true);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateTrustedStatus(String authUserId, bool newStatus) async {
    try {
      await supabase
          .from('employees')
          .update({'is_trusted': newStatus})
          .eq('auth_user_id', authUserId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateActiveStatus(String authUserId, bool isActive) async {
    try {
      await supabase
          .from('employees')
          .update({'is_employee_active': isActive})
          .eq('auth_user_id', authUserId);
    } catch (e) {
      rethrow;
    }
  }
}
