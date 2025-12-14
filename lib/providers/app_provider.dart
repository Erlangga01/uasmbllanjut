import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/material_model.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';

class AppProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Product> _products = [];
  List<MaterialModel> _materials = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Product> get products => _products;
  List<MaterialModel> get materials => _materials;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchProducts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _products = await _apiService.getProducts();
    } catch (e) {
      print('Error fetching products: $e');
      _errorMessage = 'Failed to load products: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMaterials() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _materials = await _apiService.getMaterials();
    } catch (e) {
      print('Error fetching materials: $e');
      _errorMessage = 'Failed to load materials: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<TransactionResponse> _transactions = [];
  List<TransactionResponse> get transactions => _transactions;

  Future<void> fetchTransactions() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _transactions = await _apiService.getTransactions();
      print('DEBUG: Fetched ${_transactions.length} transactions');
    } catch (e) {
      print('DEBUG: Error details: $e');
      _errorMessage = 'Gagal memuat data: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> submitTransaction(CreateTransactionDto transaction) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      bool success = await _apiService.createTransaction(transaction);
      if (success) {
        // Refresh data to show updated stock and transaction history
        await fetchMaterials(); 
        await fetchTransactions();
      } else {
        _errorMessage = 'Failed to create transaction';
      }
      return success;
    } catch (e) {
      _errorMessage = 'Error creating transaction: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
