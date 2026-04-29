import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:hore_app/main.dart';

class ProductRepository {
  // Get categories
  Future<List<Map<String, dynamic>>> getCategories() async {
    final data = await supabase.from('categories').select();
    return List<Map<String, dynamic>>.from(data);
  }

  // Get specifications based on categories
  Future<List<Map<String, dynamic>>> getSpecificationsByCategory(
    int categoryId,
  ) async {
    final data = await supabase
        .from('specifications')
        .select()
        .eq('categories_id', categoryId);
    return List<Map<String, dynamic>>.from(data);
  }

  // Add product - Generate QR - Upload product image
  Future<void> addProduct({
    required String name,
    required String code,
    required int categoryId,
    required int stock,
    required double price,
    required File imageFile,
    required Map<int, String> specificationValues,
  }) async {
    try {
      // Upload product image
      final String imageExtension = imageFile.path.split('.').last;
      final String imagePath = 'products/${DateTime.now().millisecondsSinceEpoch}.$imageExtension';

      await supabase.storage
          .from('pos-images')
          .upload(
            imagePath,
            imageFile,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );

      final String productImageUrl = supabase.storage
          .from('pos-images')
          .getPublicUrl(imagePath);

      // Generate QR Code - Format "PRODUCT_ID | PRODUCT_CODE"
      final qrValidationData = code;
      final Uint8List qrBytes = await _generateQrImage(qrValidationData);

      // Upload QR Code Image
      final String qrPath = 'qrcodes/$code-qr.png';
      await supabase.storage.from('pos-images').uploadBinary(
            qrPath,
            qrBytes,
            fileOptions: const FileOptions(contentType: 'image/png', upsert: true),
          );

      final String qrImageUrl = supabase.storage
          .from('pos-image')
          .getPublicUrl(qrPath);

      // Save product to database
      final insertedProduct = await supabase
          .from('products')
          .insert({
            'product_code': code,
            'category_id': categoryId,
            'product_name': name,
            'product_stock': stock,
            'product_price': price,
            'product_picture_url': productImageUrl,
            'product_qr_code': qrImageUrl,
            'is_product_active': true,
          })
          .select()
          .single();

      final int newProductId = insertedProduct['product_id'];

      // Save specification values to database
      if (specificationValues.isNotEmpty) {
        final List<Map<String, dynamic>> specDataToInsert = specificationValues
            .entries
            .map((entry) {
              return {
                'product_id': newProductId,
                'specification_id': entry.key,
                'value': entry.value,
              };
            })
            .toList();

        await supabase.from('specification_values').insert(specDataToInsert);
      }
    } catch (e) {
      rethrow;
    }
  }

  // Generate QR - Change text to PNG Image
  Future<Uint8List> _generateQrImage(String data) async {
    final qrValidationResult = QrValidator.validate(
      data: data,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.H,
    );

    if (qrValidationResult.status == QrValidationStatus.valid) {
      final qrCode = qrValidationResult.qrCode!;
      final painter = QrPainter.withQr(
        qr: qrCode,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Color(0XFF000000),
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Color(0XFF000000),
        ),
        gapless: true,
      );

      // Virtual canvas
      final pict = await painter.toPicture(300);
      final img = await pict.toImage(300, 300);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      return byteData!.buffer.asUint8List();
    } else {
      throw Exception('Gagal generate QR Code');
    }
  }

  Future<List<Map<String, dynamic>>> getProducts({bool isActive = true}) async {
    try {
      final data = await supabase
        .from('products')
        .select('*, categories(category_name), discounts(discount_id, discount_name, discount_value, is_discount_active)')
        .eq('is_product_active', isActive)
        .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<int, String>> getProductSpecValues(int productId) async {
    final data = await supabase
      .from('specification_values')
      .select('specification_id, value')
      .eq('product_id', productId);
    
    Map<int, String> result = {};
    for (var item in data) {
      result[item['specification_id'] as int] = item['value'].toString();
    }
    return result;
  }

  Future<void> updateProduct({
    required int productId,
    required String name,
    required int categoryId,
    required int stock,
    required double price,
    Uint8List? newImageBytes,
    String? newImageExtension,
    required Map<int, String> specificationValues,
  }) async {
    try {
      String? updatedImageUrl;

      // if user choose new image
      if (newImageBytes != null && newImageExtension != null) {
        final String imagePath = 'products/${DateTime.now().millisecondsSinceEpoch}.$newImageExtension';
        await supabase.storage.from('pos-image').uploadBinary(
          imagePath,
          newImageBytes,
          fileOptions: FileOptions(contentType: 'image/$newImageExtension', upsert: true)
        );
        updatedImageUrl = supabase.storage.from('pos-images').getPublicUrl(imagePath);
      }

      // data for update to table products
      final Map<String, dynamic> updateData = {
        'product_name': name,
        'category_id': categoryId,
        'product_stock': stock,
        'product_price': price,
      };

      if (updatedImageUrl != null) {
        updateData['product_picture_url'] = updatedImageUrl;
      }

      // update table
      await supabase.from('products').update(updateData).eq('product_id', productId);
      await supabase.from('specification_values').delete().eq('product_id', productId);

      if (specificationValues.isNotEmpty) {
        final List<Map<String, dynamic>> specDataToInsert = specificationValues.entries.map((entry) {
          return {
            'product_id': productId,
            'specification_id': entry.key,
            'value': entry.value,
          };
        }).toList();
        await supabase.from('specification_values').insert(specDataToInsert);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> disableProduct(int productId) async {
    try {
      await supabase
        .from('products')
        .update({'is_product_active': false})
        .eq('product_id', productId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> enableProduct(int productId) async {
    try {
      await supabase
        .from('products')
        .update({'is_product_active': true})
        .eq('product_id', productId);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getCompareData(List<int> productIds) async {
    try {
      final data = await supabase
        .from('specification_values')
        .select('product_id, value, specifications(specification_name, data_type, unit)')
        .inFilter('product_id', productIds)
        .order('specification_id', ascending: true);
        
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getProductDetailByCode(String code) async {
    try {
      final productList = await supabase
        .from('products')
        .select('*, categories(category_name)')
        .eq('product_code', code)
        .limit(1);
      
      if (productList.isEmpty) return null;
      final product = productList.first;

      final specsData = await supabase
        .from('specification_values')
        .select('value, specifications(specification_name, unit, data_type)')
        .eq('product_id', product['product_id']);

      return {
        'product': product,
        'specs': specsData, 
      };
    } catch (e) {
      rethrow;
    }
  }
}
