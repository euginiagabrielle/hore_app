import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hore_app/main.dart';

class AuthRepository {
  // Login function
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      // Auth to supabase
      final AuthResponse response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final String userId = response.user!.id;

      // Get employee data
      final employeeData = await supabase
        .from('employees')
        .select()
        .eq('auth_user_id', userId)
        .single();

      // Employee's active validation
      if (employeeData['is_employee_active'] == false) {
        // Force logout for inactive employee
        await supabase.auth.signOut();
        throw 'Akun tidak aktif.';
      }

      return employeeData;

    } catch (e) {
      rethrow;
    }
  }
}