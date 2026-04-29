import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as mp;
// import 'package:path/path.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HybridValidationService {
  final _supabase = Supabase.instance.client;
  final String storeWifiBSSID = "1C:E5:04:DA:E1:88";

  Future<bool> validateAccess(int employeeId, String employeeName, String role) async {
    if (role.toLowerCase() == 'owner') {
      return true;
    }
    
    // Primary validation: Wi-Fi Detection
    final info = NetworkInfo();
    String? currentBSSID = await info.getWifiBSSID();
    // print(currentBSSID);

    if (currentBSSID != null && currentBSSID.toLowerCase() == storeWifiBSSID.toLowerCase()) {
      await _logEmployeeActivity(
        employeeId: employeeId, 
        employeeName: employeeName, 
        latitude: 0.0, 
        longitude: 0.0, 
        wifiBSSID: currentBSSID,
        isMockLocator: false,
      );
      return true;
    }

    if (kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      throw Exception("Akses ditolak! Perangkat Desktop wajib terhubung ke Wi-Fi Toko.");
    }

    // Secondary validation: Polygon Geofencing
    // Get polygon points
    List<mp.LatLng> storePolygon = [];
    try {
      final locationData = await _supabase
        .from('locations')
        .select()
        .order('id', ascending: true);
      
      if (locationData.length < 3) {
        throw Exception("Sistem Error: Data titik poligon kurang dari 3!");
      }

      storePolygon = locationData.map((point) {
        return mp.LatLng((point['latitude'] as num).toDouble(), (point['longitude'] as num).toDouble());
      }).toList();
    } catch (e) {
      throw Exception("Gagal mengambil titik-titik lokasi area toko");
    }

    // Making sure the GPS is on & allowed
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception("GPS mati dan Anda tidak terhubung ke Wi-Fi toko.");

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) throw Exception("Izin GPS ditolak aplikasi.");
    }

    // Get accurate position
    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    if(position.isMocked) {
      await _logEmployeeActivity(
        employeeId: employeeId, 
        employeeName: employeeName, 
        latitude: position.latitude, 
        longitude: position.longitude, 
        wifiBSSID: currentBSSID,
        isMockLocator: true,
      );
      throw Exception("FAKE GPS TERDETEKSI!");
    }
    
    if (position.accuracy > 20.0) {
      // print("Titik: $position");
      throw Exception("Sinyal GPS tidak akurat (Toleransi: 20m, Akurasi Anda: ${position.accuracy.toStringAsFixed(1)}m).");
    }

    // Point-in-Polygon (Margin tolerance: 10m)
    mp.LatLng currentPoint = mp.LatLng(position.latitude, position.longitude);

    bool isInside = mp.PolygonUtil.containsLocation(currentPoint, storePolygon, false);
    bool isWithinTolerance = mp.PolygonUtil.isLocationOnEdge(currentPoint, storePolygon, false, tolerance: 10.0);

    if (isInside || isWithinTolerance) {
      // print("Posisi GPS tervalidasi di area toko.");
      await _logEmployeeActivity(
        employeeId: employeeId, 
        employeeName: employeeName, 
        latitude: position.latitude, 
        longitude: position.longitude, 
        wifiBSSID: currentBSSID,
        isMockLocator: false,
      );
      return true;
    } else {
      throw Exception("Anda berada di luar batas area toko. Akses ditolak!");
    }
  }

  Future<void> _logEmployeeActivity({
    required int employeeId,
    required String employeeName,
    required double latitude,
    required double longitude,
    String? wifiBSSID,
    required bool isMockLocator,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      await supabase.from('activity_logs').insert({
        'employee_id': employeeId,
        'employee_name': employeeName,
        'activity_latitude': latitude,
        'activity_longitude': longitude,
        'activity_wifi': wifiBSSID ?? 'Cellular/Tidak Terdeteksi',
        'is_mock_locator': isMockLocator,
      });

      print("Activity log berhasil disimpan ke database!");
    } catch (e) {
      print("Gagal menyimpan activity log: $e");
    }
  }
}