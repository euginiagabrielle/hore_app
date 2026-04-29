import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hore_app/features/transaction/presentation/pos_payment_page.dart';
// import 'package:path/path.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/auth/presentation/login_page.dart';
import 'dashboard_page.dart';
import 'features/employees/presentation/employee_list_page.dart';
import 'features/inventory/presentation/add_product_page.dart';
import 'features/inventory/presentation/product_list_page.dart';
import 'features/inventory/presentation/edit_product_page.dart';
import 'features/inventory/presentation/qr_scanner_page.dart';
import 'features/inventory/presentation/product_detail_page.dart';
import 'features/transaction/presentation/pos_page.dart';
import 'features/transaction/presentation/checkout_page.dart';

final go_router = GoRouter(
  initialLocation: '/',
  routes: [
    // Login Page
    GoRoute(
      path: '/',
      builder: (context, state) => const LoginPage(),
    ),

    // Admin Dashboard
    GoRoute(
      path: '/dashboard',
      builder: (context, state) {
        final userData = state.extra as Map<String, dynamic>;
        return DashboardPage(userData: userData);
      }
    ),

    // Employee Management
    GoRoute(
      path: '/employees',
      builder: (context, state) => const EmployeeListPage(),
    ),

    // Product Management
    GoRoute(
      path: '/add-product',
      builder: (context, state) => const AddProductPage(),
    ),

    GoRoute(
      path: '/edit-product',
      builder: (context, state) {
        final productData = state.extra as Map<String, dynamic>;
        return EditProductPage(product: productData);
      }
    ),

    // Product View
    GoRoute(
      path: '/products',
      builder: (context, state) {
        final String role = (state.extra as String?) ?? 'sales';
        return ProductListPage(userRole: role);
      },
    ),

    GoRoute(
      path: '/product-detail',
      builder: (context, state) {
        final String code = state.extra as String;
        return ProductDetailPage(productCode: code);
      },
    ),

    // QR Code Scan
    GoRoute(
      path: '/scan-qr',
      builder: (context, state) => const QrScannerPage(),
    ),

    // Transaction
    GoRoute(
      path: '/pos',
      builder: (context, state) => const PosPage()
    ),

    GoRoute(
      path: '/checkout',
      builder: (context, state) => const CheckoutPage()
    ),

    GoRoute(
      path: '/pos-payment',
      builder: (context, state) {
        final Map<String, dynamic> extra = state.extra as Map<String, dynamic>;
        return PosPaymentPage(
          orderId: extra['orderId'], 
          totalPrice: extra ['totalPrice'],
        );
      },
    ),
  ]
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase Initialization
  await Supabase.initialize(
    url: 'https://dlhxreovplnctgidanjy.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRsaHhyZW92cGxuY3RnaWRhbmp5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc3NjU0NTQsImV4cCI6MjA4MzM0MTQ1NH0.j8RBMMEHCFXl9jUsez2IpxYFMB-0vdIJZHBXv3OS4uE',
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: go_router,
      title: "Hore Electronic POS",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      // home: const LoginPage(),
    );
  }
}