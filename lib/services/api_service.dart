import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../models/material_model.dart';
import '../models/transaction.dart';

class ApiService {
  // Determine Base URL based on platform
  // API documentation specifies all endpoints are prefixed with /api
  String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost/advweb_uas/api';
    } else if (Platform.isAndroid) {
      return 'http://192.168.68.223/advweb_uas/api';
    } else {
      return 'http://localhost/advweb_uas/api'; // Default fallback
    }
  }

  Future<List<Product>> getProducts() async {
    final response = await http.get(Uri.parse('$baseUrl/products'));

    if (response.statusCode == 200) {
      dynamic body = jsonDecode(response.body);
      List<dynamic> list = (body is Map && body.containsKey('data')) ? body['data'] : body;
      return list.map((dynamic item) => Product.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load products: ${response.statusCode}');
    }
  }

  Future<List<MaterialModel>> getMaterials() async {
    final response = await http.get(Uri.parse('$baseUrl/materials'));

    if (response.statusCode == 200) {
      dynamic body = jsonDecode(response.body);
      List<dynamic> list = (body is Map && body.containsKey('data')) ? body['data'] : body;
      return list.map((dynamic item) => MaterialModel.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load materials: ${response.statusCode}');
    }
  }

  Future<List<TransactionResponse>> getTransactions() async {
    final response = await http.get(Uri.parse('$baseUrl/transactions'));

    if (response.statusCode == 200) {
      dynamic body = jsonDecode(response.body);

      print('DEBUG: Raw Transaction Response: $body'); // Debug print

      List<dynamic> list = [];
      if (body is Map) {
        if (body.containsKey('data')) {
           var dataContent = body['data'];
           if (dataContent is List) {
             list = dataContent;
           } else if (dataContent is Map && dataContent.containsKey('data') && dataContent['data'] is List) {
             // Handle Laravel Pagination: { "data": { "data": [...] } }
             list = dataContent['data'];
           }
        } else if (body.containsKey('transactions') && body['transactions'] is List) {
            list = body['transactions'];
        }
      } else if (body is List) {
        list = body;
      }
      
      print('DEBUG: Parsed List Length: ${list.length}');
      var parsedList = list.map((dynamic item) => TransactionResponse.fromJson(item)).toList();
      print('DEBUG: Parsed Data: $parsedList');
      return parsedList;
    } else {
      throw Exception('Failed to load transactions: ${response.statusCode} - ${response.body}');
    }
  }

  Future<bool> createTransaction(CreateTransactionDto transaction) async {
      print('DEBUG: Create Transaction Body: ${jsonEncode(transaction.toJson())}');
      final response = await http.post(
      Uri.parse('$baseUrl/transactions'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      },
      body: jsonEncode(transaction.toJson()),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return true;
    } else {
      print('Transaction failed: ${response.body}');
      return false;
    }
  }
}
