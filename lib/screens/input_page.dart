import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../providers/app_provider.dart';
import '../models/product.dart';
import '../models/transaction.dart';
import '../models/cart_item.dart';
import '../services/print_thermal.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:permission_handler/permission_handler.dart';

class InputPage extends StatefulWidget {
  const InputPage({super.key});

  @override
  State<InputPage> createState() => _InputPageState();
}

class _InputPageState extends State<InputPage> {
  final _formKey = GlobalKey<FormState>(); // Key for the "Add Item" form
  final _customerController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _unitController = TextEditingController(text: 'Pcs');
  final _dateController = TextEditingController(
    text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
  );
  final _vatController = TextEditingController(text: '10'); // Default 10% VAT

  Product? _selectedProduct;
  final List<CartItem> _cart = [];
  bool _shouldPrintReceipt = true; // Default to printing

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().fetchProducts();
      // Ensure we have latest transactions for the recent activity list
      context.read<AppProvider>().fetchTransactions();
    });
  }

  @override
  void dispose() {
    _customerController.dispose();
    _qtyController.dispose();
    _unitController.dispose();
    _dateController.dispose();
    _vatController.dispose();
    super.dispose();
  }

  // Calculate total for the specific item being added
  String get _currentInputPrice {
    if (_selectedProduct == null) return '0';
    int qty = int.tryParse(_qtyController.text) ?? 0;
    double total = _selectedProduct!.price * qty;
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(total);
  }

  // Calculate total for the entire cart
  double get _cartTotal {
    return _cart.fold(0, (sum, item) => sum + item.totalPrice);
  }

  double get _vatAmount {
    double vatPercent = double.tryParse(_vatController.text) ?? 10.0;
    return _cartTotal * (vatPercent / 100);
  }

  double get _grandTotal {
    return _cartTotal + _vatAmount;
  }

  void _addToCart() {
    if (_formKey.currentState!.validate() && _selectedProduct != null) {
      int qty = int.tryParse(_qtyController.text) ?? 0;
      if (qty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Jumlah harus lebih dari 0')),
        );
        return;
      }

      setState(() {
        // Check if product already exists in cart
        int existingIndex = _cart.indexWhere(
          (item) => item.product.id == _selectedProduct!.id,
        );
        if (existingIndex != -1) {
          _cart[existingIndex].quantity += qty;
        } else {
          _cart.add(
            CartItem(
              product: _selectedProduct!,
              quantity: qty,
              unit: _unitController.text,
            ),
          );
        }

        // Reset product input only
        _selectedProduct = null;
        _qtyController.text = '1';
        _unitController.text = 'Pcs';
      });
    } else if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih produk terlebih dahulu')),
      );
    }
  }

  void _showEditDialog(int index, CartItem item) {
    final nameController = TextEditingController(text: item.name);
    final priceController = TextEditingController(
      text: item.price.toStringAsFixed(0),
    );
    final qtyController = TextEditingController(text: item.quantity.toString());
    final unitController = TextEditingController(text: item.unit);
    final discountController = TextEditingController(
      text: item.discountPercent.toString(),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nama Produk'),
                ),
                TextFormField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Harga'),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: qtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Qty'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: unitController,
                        decoration: const InputDecoration(labelText: 'Satuan'),
                      ),
                    ),
                  ],
                ),
                TextFormField(
                  controller: discountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Diskon (%)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  item.name = nameController.text;
                  item.price =
                      double.tryParse(priceController.text) ?? item.price;
                  item.quantity =
                      int.tryParse(qtyController.text) ?? item.quantity;
                  item.unit = unitController.text;
                  item.discountPercent =
                      double.tryParse(discountController.text) ?? 0.0;
                });
                Navigator.pop(context);
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _removeFromCart(int index) {
    setState(() {
      _cart.removeAt(index);
    });
  }

  void _submitTransaction() async {
    if (_customerController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Harap isi nama pelanggan')));
      return;
    }
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Keranjang masih kosong')));
      return;
    }

    // Capture local state for printing before clearing (or use these variables)
    // We need to keep a reference to the data to print AFTER submission validation
    final localCartForPrint = List<CartItem>.from(_cart);
    final localCustomerName = _customerController.text;
    final localDate = _dateController.text;
    final localGrandTotal = _grandTotal;
    final localVatPercent = double.tryParse(_vatController.text) ?? 10.0;

    final transaction = CreateTransactionDto(
      customerName: _customerController.text,
      transactionDate: _dateController.text,
      subTotal: _cartTotal,
      items:
          _cart
              .map(
                (item) => TransactionItem(
                  productId: item.product.id,
                  quantity: item.quantity,
                  name: item.name,
                  unit: item.unit,
                  price: item.price,
                  totalPrice: item.totalPrice,
                  discountPercent: item.discountPercent,
                ),
              )
              .toList(),
      vat: localVatPercent,
    );

    bool success = await context.read<AppProvider>().submitTransaction(
      transaction,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi Berhasil! Stok terupdate.')),
        );
        _customerController.clear();
        setState(() {
          _cart.clear();
          _selectedProduct = null;
          _qtyController.text = '1';
        });

        // Promt to print or auto-print based on checkbox
        // We use the Local Data for printing to ensure accuracy (edits, discounts),
        // but we try to get the ID from the latest transaction fetched from server.
        final latestTransactions = context.read<AppProvider>().transactions;

        int transactionId = 0;
        DateTime createdAt = DateTime.now();

        if (latestTransactions.isNotEmpty) {
          // Sort by ID desc to get the latest just in case
          final latest = latestTransactions.reduce(
            (curr, next) => curr.id > next.id ? curr : next,
          );
          transactionId = latest.id;
          createdAt = latest.createdAt;
        }

        // Construct a receipt object using LOCAL data + Server ID
        final receiptData = TransactionResponse(
          id: transactionId,
          customerName: localCustomerName,
          transactionDate: localDate,
          totalAmount: localGrandTotal,
          createdAt: createdAt,
          tax: localVatPercent,
          items:
              localCartForPrint.map((cartItem) {
                return TransactionDetailResponse(
                  id: 0, // Not needed for print
                  productId: cartItem.product.id,
                  quantity: cartItem.quantity,
                  price: cartItem.price,
                  productName: cartItem.name, // Use edited name
                  discountPercent: cartItem.discountPercent,
                  totalPrice: cartItem.totalPrice,
                );
              }).toList(),
        );

        if (_shouldPrintReceipt) {
          _processPrint(receiptData);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.read<AppProvider>().errorMessage ?? 'Gagal menyimpan',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Transaction Header (Customer & Date)
              _buildTransactionHeader(),

              const SizedBox(height: 20),

              // 2. Add Item Form
              _buildAddItemForm(provider),

              const SizedBox(height: 24),

              // 3. Cart List
              const Text(
                'Daftar Belanja',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildCartList(),

              const SizedBox(height: 24),

              // 4. Print Option
              CheckboxListTile(
                value: _shouldPrintReceipt,
                onChanged: (val) {
                  setState(() {
                    _shouldPrintReceipt = val ?? true;
                  });
                },
                title: const Text('Cetak Struk Transaksi'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF2563EB),
              ),

              const SizedBox(height: 12),

              // VAT Input
              TextFormField(
                controller: _vatController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'PPN / VAT (%)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.percent),
                ),
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 12),

              // 5. Submit Button
              _buildSubmitButton(provider),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransactionHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Data Penjualan',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          // Date
          TextFormField(
            controller: _dateController,
            decoration: const InputDecoration(
              labelText: 'Tanggal',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today),
            ),
            readOnly: true,
            onTap: () async {
              DateTime? pickedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2101),
              );
              if (pickedDate != null) {
                setState(() {
                  _dateController.text = DateFormat(
                    'yyyy-MM-dd',
                  ).format(pickedDate);
                });
              }
            },
          ),
          const SizedBox(height: 12),
          // Customer
          TextFormField(
            controller: _customerController,
            decoration: const InputDecoration(
              labelText: 'Nama Pelanggan',
              hintText: 'Contoh: Pak Budi',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddItemForm(AppProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tambah Produk',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),

            // Product Dropdown
            DropdownButtonFormField<Product>(
              value: _selectedProduct,
              isExpanded: true,
              hint: const Text('Pilih Produk'),
              items:
                  provider.products
                      .map(
                        (p) => DropdownMenuItem(value: p, child: Text(p.name)),
                      )
                      .toList(),
              onChanged: (val) => setState(() => _selectedProduct = val),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Qty',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _unitController,
                    decoration: const InputDecoration(
                      labelText: 'Satuan',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    alignment: Alignment.centerRight,
                    child: Text(
                      _currentInputPrice,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addToCart,
                icon: const Icon(Icons.add_shopping_cart, size: 18),
                label: const Text('Tambah ke Keranjang'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade50,
                  foregroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartList() {
    if (_cart.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(
              Icons.shopping_basket_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              'Keranjang Kosong',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _cart.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = _cart[index];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          item.discountPercent > 0
                              ? '${item.quantity} ${item.unit} x ${NumberFormat.simpleCurrency(locale: 'id_ID', decimalDigits: 0).format(item.price)} (Disc ${item.discountPercent.toStringAsFixed(0)}%)'
                              : '${item.quantity} ${item.unit} x ${NumberFormat.simpleCurrency(locale: 'id_ID', decimalDigits: 0).format(item.price)}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    NumberFormat.simpleCurrency(
                      locale: 'id_ID',
                      decimalDigits: 0,
                    ).format(item.totalPrice),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _showEditDialog(index, item),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _removeFromCart(index),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade900,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Subtotal',
                    style: TextStyle(color: Colors.white70),
                  ),
                  Text(
                    NumberFormat.simpleCurrency(
                      locale: 'id_ID',
                      decimalDigits: 0,
                    ).format(_cartTotal),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'PPN (${_vatController.text}%)',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Text(
                    NumberFormat.simpleCurrency(
                      locale: 'id_ID',
                      decimalDigits: 0,
                    ).format(_vatAmount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Transaksi',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  Text(
                    NumberFormat.currency(
                      locale: 'id_ID',
                      symbol: 'Rp ',
                      decimalDigits: 0,
                    ).format(_grandTotal),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(AppProvider provider) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: provider.isLoading ? null : _submitTransaction,
        icon:
            provider.isLoading
                ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                : const FaIcon(FontAwesomeIcons.solidFloppyDisk, size: 18),
        label: Text(provider.isLoading ? 'Menyimpan...' : ' Transaksi'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB), // blue-600
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          disabledBackgroundColor: Colors.blue.shade300,
        ),
      ),
    );
  }

  // Printing Logic

  Future<void> _processPrint(TransactionResponse transaction) async {
    // 1. Check Permissions
    if (await Permission.bluetoothConnect.request().isGranted &&
        await Permission.bluetoothScan.request().isGranted &&
        await Permission.location.request().isGranted) {
      // 2. Check Connection
      // 2. Try Print (Auto-connect is handled inside)
      bool success = await PrintThermal.printReceipt(transaction);

      if (!success) {
        // Fallback: If auto-connect fails, show manual selection or error
        if (mounted) {
          _showDeviceSelection(transaction);
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Izin Bluetooth diperlukan untuk mencetak'),
          ),
        );
      }
    }
  }

  void _showDeviceSelection(TransactionResponse transaction) async {
    List<BluetoothDevice> devices = [];
    try {
      devices = await PrintThermal.bluetooth.getBondedDevices();
    } catch (e) {
      // ignore
    }

    if (devices.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada printer terpasang ditemukan'),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder:
          (ctx) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pilih Printer',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 12),
                ...devices.map(
                  (device) => ListTile(
                    title: Text(device.name ?? 'Unknown'),
                    subtitle: Text(device.address ?? ''),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      try {
                        await PrintThermal.bluetooth.connect(device);
                        await PrintThermal.printReceipt(transaction);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gagal koneksi: $e')),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
