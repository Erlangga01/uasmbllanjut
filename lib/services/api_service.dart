import 'dart:convert';
import 'dart:io';
import 'dart:developer' as dev;
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
    final url = Uri.parse('$baseUrl/products');
    dev.log('GET Request: $url', name: 'API');

    final response = await http.get(
      url,
      headers: {'Accept': 'application/json'},
    );

    dev.log('GET Response: ${response.statusCode}', name: 'API');
    dev.log('Response Body: ${response.body}', name: 'API');

    if (response.statusCode == 200) {
      dynamic body = jsonDecode(response.body);
      List<dynamic> list =
          (body is Map && body.containsKey('data')) ? body['data'] : body;
      return list.map((dynamic item) => Product.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load products: ${response.statusCode}');
    }
  }

  Future<List<MaterialModel>> getMaterials() async {
    final url = Uri.parse('$baseUrl/materials');
    dev.log('GET Request: $url', name: 'API');

    final response = await http.get(
      url,
      headers: {'Accept': 'application/json'},
    );

    dev.log('GET Response: ${response.statusCode}', name: 'API');
    dev.log('Response Body: ${response.body}', name: 'API');

    if (response.statusCode == 200) {
      dynamic body = jsonDecode(response.body);
      List<dynamic> list =
          (body is Map && body.containsKey('data')) ? body['data'] : body;
      return list.map((dynamic item) => MaterialModel.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load materials: ${response.statusCode}');
    }
  }

  Future<List<TransactionResponse>> getTransactions() async {
    final url = Uri.parse('$baseUrl/transactions');
    dev.log('GET Request: $url', name: 'API');

    final response = await http.get(
      url,
      headers: {'Accept': 'application/json'},
    );

    dev.log('GET Response: ${response.statusCode}', name: 'API');
    dev.log('Response Body: ${response.body}', name: 'API');

    if (response.statusCode == 200) {
      dynamic body = jsonDecode(response.body);

      dev.log(
        'DEBUG: Raw Transaction Response: $body',
        name: 'API',
      ); // Debug log

      List<dynamic> list = [];
      if (body is Map) {
        if (body.containsKey('data')) {
          var dataContent = body['data'];
          if (dataContent is List) {
            list = dataContent;
          } else if (dataContent is Map &&
              dataContent.containsKey('data') &&
              dataContent['data'] is List) {
            // Handle Laravel Pagination: { "data": { "data": [...] } }
            list = dataContent['data'];
          }
        } else if (body.containsKey('transactions') &&
            body['transactions'] is List) {
          list = body['transactions'];
        }
      } else if (body is List) {
        list = body;
      }

      dev.log('DEBUG: Parsed List Length: ${list.length}', name: 'API');
      var parsedList =
          list
              .map((dynamic item) => TransactionResponse.fromJson(item))
              .toList();
      dev.log('DEBUG: Parsed Data: $parsedList', name: 'API');
      return parsedList;
    } else {
      String errorMessage =
          'Failed to load transactions: ${response.statusCode}';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body.containsKey('message')) {
          errorMessage += ' - ${body['message']}';
        } else {
          // Shorten body if it's HTML or too long
          errorMessage +=
              ' - ${response.body.length > 100 ? response.body.substring(0, 100) + "..." : response.body}';
        }
      } catch (_) {
        errorMessage +=
            ' - ${response.body.length > 100 ? response.body.substring(0, 100) + "..." : response.body}';
      }
      throw Exception(errorMessage);
    }
  }

  Future<bool> createTransaction(CreateTransactionDto transaction) async {
    final url = Uri.parse('$baseUrl/transactions');
    final body = jsonEncode(transaction.toJson());

    dev.log('POST Request: $url', name: 'API');
    dev.log('Request Body: $body', name: 'API');

    final response = await http.post(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      },
      body: body,
    );

    dev.log('POST Response: ${response.statusCode}', name: 'API');
    dev.log('Response Body: ${response.body}', name: 'API');

    if (response.statusCode == 201 || response.statusCode == 200) {
      return true;
    } else {
      dev.log(
        'Transaction failed: ${response.body}',
        name: 'API',
        error: response.body,
      );
      return false;
    }
  }
}
