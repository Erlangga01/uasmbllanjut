// Import pustaka inti Dart untuk konversi JSON (jsonDecode/jsonEncode)
import 'dart:convert';
// Import pustaka Dart untuk akses IO (Input/Output) seperti deteksi OS (Platform)
import 'dart:io';
// Import pustaka developer untuk logging yang lebih baik daripada print()
import 'dart:developer' as dev;
// Import Flutter Foundation untuk konstanta kIsWeb (cek apakah jalan di Web)
import 'package:flutter/foundation.dart';
// Import paket HTTP untuk melakukan request ke API (GET, POST, dll)
import 'package:http/http.dart' as http;
// Import model-model data untuk memetakan respon JSON ke objek Dart
import '../models/product.dart';
import '../models/material_model.dart';
import '../models/transaction.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();

  factory ApiService() {
    return _instance;
  }

  ApiService._internal();
  // Token authentication
  String? _token;

  void setToken(String? token) {
    _token = token;
  }

  String? get token => _token;

  // Properti untuk mendapatkan URL dasar API secara dinamis berdasarkan platform
  String get baseUrl {
    // Cek apakah aplikasi berjalan di Browser (Web)
    if (kIsWeb) {
      // Jika Web, 'localhost' mengacu pada komputer server/host
      return 'http://localhost/advweb_uas/api';
    }
    // Cek apakah aplikasi berjalan di Android (Fisik atau Emulator)
    else if (Platform.isAndroid) {
      // Jika Android, 'localhost' adalah HP itu sendiri.
      // Jadi harus pakai IP Address LAN PC host (ganti sesuai IP PC Anda)
      return 'http://192.168.2.100/advweb_uas/api';
    } else {
      // Fallback default untuk platform lain (iOS/Desktop)
      return 'http://localhost/advweb_uas/api';
    }
  }

  // Helper untuk header dengan Token
  Map<String, String> get headers {
    var headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=UTF-8',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // Login
  Future<String> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/login');
    final body = jsonEncode({'email': email, 'password': password});

    dev.log('POST Login Request: $url', name: 'API');

    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: body,
    );

    dev.log('Login Response: ${response.statusCode}', name: 'API');
    dev.log('Response Body: ${response.body}', name: 'API');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Sesuaikan dengan respon Sanctum, biasanya { access_token: "..." } atau { token: "..." }
      if (data['access_token'] != null) {
        return data['access_token'];
      } else if (data['token'] != null) {
        return data['token'];
      }
      throw Exception('Token not found in response');
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Login failed');
    }
  }

  // Register
  Future<bool> register(String name, String email, String password) async {
    final url = Uri.parse('$baseUrl/register');
    final body = jsonEncode({
      'name': name,
      'email': email,
      'password': password,
      // Default role or logic if needed
    });

    dev.log('POST Register Request: $url', name: 'API');

    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: body,
    );
    dev.log('Register Response: ${response.statusCode}', name: 'API');
    dev.log('Response Body: ${response.body}', name: 'API');

    if (response.statusCode == 201 || response.statusCode == 200) {
      return true;
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Registration failed');
    }
  }

  // Logout (Optional: Call API to revoke token)
  Future<void> logout() async {
    // Jika API punya endpoint logout
    // final url = Uri.parse('$baseUrl/logout');
    // await http.post(url, headers: headers);

    _token = null;
  }

  // Fungsi untuk mengambil daftar Produk dari server (Method GET)
  Future<List<Product>> getProducts() async {
    // Menyusun URL lengkap endpoint products
    final url = Uri.parse('$baseUrl/products');
    // Mencatat log request untuk debugging
    dev.log('GET Request: $url', name: 'API');

    // Melakukan request HTTP GET ke server
    final response = await http.get(
      url,
      // Mengirim header agar server tahu kita meminta format JSON
      headers: headers, // USE THE HEADERS PROPERTY
    );

    // Mencatat log respon status dan body dari server
    dev.log('GET Response: ${response.statusCode}', name: 'API');
    dev.log('Response Body: ${response.body}', name: 'API');

    // Cek apakah status code 200 (OK / Berhasil)
    if (response.statusCode == 200) {
      // Parsing body respon dari String JSON ke Dynamic Object
      dynamic body = jsonDecode(response.body);

      // Logika untuk mengambil list data.
      // Jika body berupa Map dan punya key 'data', ambil isinya (gaya Laravel standard).
      // Jika tidak (langsung List), ambil body-nya langsung.
      List<dynamic> list =
          (body is Map && body.containsKey('data')) ? body['data'] : body;

      // Mengubah (Map) setiap item JSON menjadi objek Product dan mengembalikannya sebagai List
      return list.map((dynamic item) => Product.fromJson(item)).toList();
    } else {
      // Jika gagal, lempar error dengan pesan status code
      throw Exception('Failed to load products: ${response.statusCode}');
    }
  }

  // Fungsi untuk mengambil daftar Material (Bahan) dari server (Method GET)
  Future<List<MaterialModel>> getMaterials() async {
    // Menyusun URL lengkap endpoint materials
    final url = Uri.parse('$baseUrl/materials');
    // Log request
    dev.log('GET Request: $url', name: 'API');

    // Request HTTP GET
    final response = await http.get(
      url,
      headers: headers, // USE THE HEADERS PROPERTY
    );

    // Log response
    dev.log('GET Response: ${response.statusCode}', name: 'API');
    dev.log('Response Body: ${response.body}', name: 'API');

    // Cek sukses 200
    if (response.statusCode == 200) {
      // Decode JSON String
      dynamic body = jsonDecode(response.body);
      // Ekstrak list data (menangani wrapper 'data' jika ada)
      List<dynamic> list =
          (body is Map && body.containsKey('data')) ? body['data'] : body;
      // Konversi ke List<MaterialModel>
      return list.map((dynamic item) => MaterialModel.fromJson(item)).toList();
    } else {
      // Throw error jika gagal
      throw Exception('Failed to load materials: ${response.statusCode}');
    }
  }

  // Fungsi untuk mengambil daftar Transaksi dari server (Method GET)
  Future<List<TransactionResponse>> getTransactions() async {
    // Menyusun URL endpoint transactions
    final url = Uri.parse('$baseUrl/transactions');
    // Log request
    dev.log('GET Request: $url', name: 'API');

    // Request HTTP GET
    final response = await http.get(
      url,
      headers: headers, // USE THE HEADERS PROPERTY
    );

    // Log response
    dev.log('GET Response: ${response.statusCode}', name: 'API');
    dev.log('Response Body: ${response.body}', name: 'API');

    // Jika respon sukses (200 OK)
    if (response.statusCode == 200) {
      // Decode JSON body
      dynamic body = jsonDecode(response.body);

      // Debugging: Log hasil decode mentah
      dev.log('DEBUG: Raw Transaction Response: $body', name: 'API');

      // Logika kompleks untuk menangani berbagai format respon dari Laravel
      List<dynamic> list = [];

      // Cek apakah body berupa Map (Object JSON {})
      if (body is Map) {
        // Cek 1: Apakah ada key 'data' (Format standar Resource/Pagination)
        if (body.containsKey('data')) {
          var dataContent = body['data'];

          // Jika 'data' isinya langsung List [] -> Ambil
          if (dataContent is List) {
            list = dataContent;
          }
          // Jika 'data' isinya Map lagi dan punya 'data' lagi (Format Pagination Laravel)
          // Contoh: { data: { current_page: 1, data: [...] } }
          else if (dataContent is Map &&
              dataContent.containsKey('data') &&
              dataContent['data'] is List) {
            list = dataContent['data'];
          }
        }
        // Cek 2: Apakah ada key khusus 'transactions'
        else if (body.containsKey('transactions') &&
            body['transactions'] is List) {
          list = body['transactions'];
        }
      }
      // Cek 3: Apakah body langsung berupa List [] (Jarang, tapi mungkin)
      else if (body is List) {
        list = body;
      }

      // Log jumlah item yang berhasil di-parse
      dev.log('DEBUG: Parsed List Length: ${list.length}', name: 'API');

      // Mapping dari JSON ke objek TransactionResponse
      var parsedList =
          list
              .map((dynamic item) => TransactionResponse.fromJson(item))
              .toList();
      dev.log('DEBUG: Parsed Data: $parsedList', name: 'API');
      return parsedList;
    } else {
      // Penanganan Error yang lebih mendetail
      String errorMessage =
          'Failed to load transactions: ${response.statusCode}';
      try {
        // Coba baca pesan error dari JSON server jika ada
        final body = jsonDecode(response.body);
        if (body is Map && body.containsKey('message')) {
          errorMessage += ' - ${body['message']}';
        } else {
          // Jika tidak ada message, tampilkan potongan body
          errorMessage +=
              ' - ${response.body.length > 100 ? "${response.body.substring(0, 100)}..." : response.body}';
        }
      } catch (_) {
        // Jika decode gagal, tampilkan raw body dipotong
        errorMessage +=
            ' - ${response.body.length > 100 ? "${response.body.substring(0, 100)}..." : response.body}';
      }
      throw Exception(errorMessage);
    }
  }

  // Fungsi untuk mengirim Transaksi Baru ke server (Method POST)
  Future<bool> createTransaction(CreateTransactionDto transaction) async {
    // Menyusun URL endpoint transactions
    final url = Uri.parse('$baseUrl/transactions');
    // Mengubah objek transaksi menjadi String JSON
    final body = jsonEncode(transaction.toJson());

    // Log data yang akan dikirim
    dev.log('POST Request: $url', name: 'API');
    dev.log('Request Body: $body', name: 'API');

    // Melakukan Request HTTP POST
    final response = await http.post(
      url,
      headers: headers, // USE THE HEADERS PROPERTY
      // Isi data body
      body: body,
    );

    // Log hasil respon POST
    dev.log('POST Response: ${response.statusCode}', name: 'API');
    dev.log('Response Body: ${response.body}', name: 'API');

    // Cek sukses: 201 (Created) atau 200 (OK)
    if (response.statusCode == 201 || response.statusCode == 200) {
      return true; // Berhasil
    } else {
      // Jika gagal, log errornya
      dev.log(
        'Transaction failed: ${response.body}',
        name: 'API',
        error: response.body,
      );
      return false; // Gagal
    }
  }
}
