import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:hore_app/features/auth/presentation/auth_gate.dart';
import 'features/auth/presentation/login_page.dart';

import 'dashboard_page.dart';
import 'features/management/presentation/management_dashboard_page.dart'; 
import 'features/management/presentation/category_management_page.dart';
import 'features/management/presentation/payment_method_management_page.dart';
import 'features/management/presentation/discount_management_page.dart';
import 'features/management/presentation/specification_management_page.dart';
import 'features/management/presentation/customer_managemt_page.dart';
import 'features/management/presentation/employee_management_page.dart';

import 'features/management/presentation/edit_product_page.dart';
import 'features/management/presentation/add_product_page.dart';
import 'features/management/presentation/product_management_page.dart';

import 'features/reports/presentation/report_dashboard_page.dart';
import 'features/reports/presentation/order_history_page.dart';
import 'features/reports/presentation/activity_log_page.dart';

import 'features/catalog/product_list_page.dart';
import 'features/catalog/qr_scanner_page.dart';
import 'features/catalog/product_detail_page.dart';

import 'features/transaction/presentation/pos_page.dart';
import 'features/transaction/presentation/pos_payment_page.dart';
import 'features/transaction/presentation/checkout_page.dart';

final go_router = GoRouter(
  initialLocation: '/',
  routes: [
    // Auth Gate
    GoRoute(
      path: '/',
      builder: (context, state) => const AuthGate(),
    ),

    // Login
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),

    // Admin Dashboard
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardPage(),
    ),

    // Reports
    GoRoute(
      path: '/reports',
      builder: (context, state) => const ReportDashboardPage(),
    ),

    // Order History
    GoRoute(
      path: '/order-history',
      builder: (context, state) => const OrderHistoryPage(),
    ),

    // Activity Log
    GoRoute(
      path: '/activity-log',
      builder: (context, state) => const ActivityLogPage(),
    ),

    // Management Dashboard
    GoRoute(
      path: '/management',
      builder: (context, state) => const ManagementDashboardPage(),
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

    // Product Management
    GoRoute(
      path: '/manage-product',
      builder: (context, state) => const ProductManagementPage(),
    ),

    // Category Management
    GoRoute(
      path: '/manage-category',
      builder: (context, state) => const CategoryManagementPage(),
    ),

    // Payment Method Management
    GoRoute(
      path: '/manage-payment-method',
      builder: (context, state) => const PaymentMethodManagementPage(),
    ),

    // Discount Management
    GoRoute(
      path: '/manage-discount',
      builder: (context, state) => const DiscountManagementPage(),
    ),

    // Specification Management
    GoRoute(
      path: '/manage-specification',
      builder: (context, state) => const SpecificationManagementPage()
    ),

    // Customer Management
    GoRoute(
      path: '/manage-customer',
      builder: (context, state) => const CustomerManagemtPage()
    ),

    // Employee Management
    GoRoute(
      path: '/employees',
      builder: (context, state) => const EmployeeManagementPage(),
    ),

    // Katalog Product
    GoRoute(
      path: '/catalog',
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

  await initializeDateFormatting('id_ID', null);

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