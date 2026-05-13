import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorHandler {
  static String getMessage(dynamic error) {

    // 1. Tangani Error dari Database (Supabase / PostgreSQL)
    if (error is PostgrestException) {
      switch (error.code) {
        case '23505': // Unique violation (Data kembar)
          return 'Data ini sudah ada di sistem. Silakan gunakan nama atau kode lain.';
        case '23503': // Foreign key violation (Data sedang dipakai)
          return 'Data tidak bisa dihapus karena masih digunakan di transaksi atau menu lain.';
        case '23502': // Not null violation (Ada kolom wajib yang kosong)
          return 'Mohon lengkapi semua data yang wajib diisi.';
        case 'PGRST116': // Data tidak ditemukan
          return 'Data tidak ditemukan di database.';
        default:
          // Jika ada error database lain yang belum dipetakan
          return 'Terjadi masalah pada database. Silakan coba lagi.';
      }
    }

    // 2. Tangani Error Autentikasi (Login / Register)
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('invalid login') || msg.contains('invalid credentials')) {
        return 'Email atau password yang Anda masukkan salah.';
      } else if (msg.contains('already registered') || msg.contains('user already exists')) {
        return 'Email ini sudah terdaftar. Silakan gunakan email lain.';
      } else if (msg.contains('password should be at least')) {
        return 'Password terlalu pendek. Gunakan minimal 6 karakter.';
      } else if (msg.contains('rate limit')) {
        return 'Terlalu banyak percobaan. Silakan tunggu beberapa saat lalu coba lagi.';
      }
      return 'Masalah Autentikasi: ${error.message}';
    }

    // 3. Tangani Error Jaringan / Internet
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('socketexception') || 
        errorString.contains('connection') || 
        errorString.contains('failed host lookup') ||
        errorString.contains('timeout')) {
      return 'Gagal terhubung ke server. Periksa koneksi internet Anda.';
    }

    // 4. Tangani Exception Biasa (yang kita buat sendiri dengan throw Exception)
    if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    }

    // 5. Default Error (Jika error tidak dikenali)
    return 'Terjadi kesalahan sistem. Silakan coba beberapa saat lagi.';
  }
}