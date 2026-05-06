import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:hore_app/features/transaction/data/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import '../../../dashboard_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();

    // Signal Radar (Berjalan di background)
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (!results.contains(ConnectivityResult.none)) {
        print("Sinyal kembali! Melakukan sinkronisasi...");

        SyncService().syncOfflineOrdersToSupabase().then((_) {
          print("Sinkronisasi sukses.");
        }).catchError((e) {
          print("Sinkronisasi gagal: $e");
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Colors.orange)),
          );
        }

        final session = snapshot.hasData ? snapshot.data!.session : null;
        
        if (session != null) {
          return DashboardPage();
        } else {
          return const LoginPage();
        }
      }
    );
  }
}