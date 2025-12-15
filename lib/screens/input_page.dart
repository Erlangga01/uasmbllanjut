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
  final _dateController = TextEditingController(
    text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
  );

  Product? _selectedProduct;
  final List<CartItem> _cart = [];

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
    _dateController.dispose();
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
          _cart.add(CartItem(product: _selectedProduct!, quantity: qty));
        }

        // Reset product input only
        _selectedProduct = null;
        _qtyController.text = '1';
      });
    } else if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih produk terlebih dahulu')),
      );
    }
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

    final transaction = CreateTransactionDto(
      customerName: _customerController.text,
      transactionDate: _dateController.text,
      items:
          _cart
              .map(
                (item) => TransactionItem(
                  productId: item.product.id,
                  quantity: item.quantity,
                ),
              )
              .toList(),
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

        // Prompt to print
        final latestTransactions = context.read<AppProvider>().transactions;
        if (latestTransactions.isNotEmpty) {
          // Sort by ID desc to get the latest just in case
          // Creating a copy to avoid modifying provider list if it matters, though sort is in place usu.
          // Safe way:
          final latest = latestTransactions.reduce(
            (curr, next) => curr.id > next.id ? curr : next,
          );
          _showPrintDialog(latest);
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

              // 4. Submit Button
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
            color: Colors.black.withOpacity(0.05),
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
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.05),
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
                          item.product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${item.quantity} x ${NumberFormat.simpleCurrency(locale: 'id_ID', decimalDigits: 0).format(item.product.price)}',
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
          child: Row(
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
                ).format(_cartTotal),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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
        label: Text(provider.isLoading ? 'Menyimpan...' : 'Simpan Transaksi'),
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
  Future<void> _showPrintDialog(TransactionResponse transaction) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Transaksi Berhasil'),
            content: const Text('Apakah anda ingin mencetak struk?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
                child: const Text('Tidak'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _processPrint(transaction);
                },
                child: const Text('Cetak'),
              ),
            ],
          ),
    );
  }

  Future<void> _processPrint(TransactionResponse transaction) async {
    // 1. Check Permissions
    if (await Permission.bluetoothConnect.request().isGranted &&
        await Permission.bluetoothScan.request().isGranted &&
        await Permission.location.request().isGranted) {
      // 2. Check Connection
      bool? isConnected = await PrintThermal.bluetooth.isConnected;
      if (isConnected == true) {
        await PrintThermal.printReceipt(transaction);
      } else {
        // Try to auto-connect to "Accessgo" or "Accesgo"
        List<BluetoothDevice> bondedDevices = [];
        try {
          bondedDevices = await PrintThermal.bluetooth.getBondedDevices();
        } catch (e) {
          // ignore
        }

        BluetoothDevice? targetDevice;
        try {
          targetDevice = bondedDevices.firstWhere(
            (d) => (d.name ?? '').toLowerCase().contains('acces'),
          );
        } catch (e) {
          targetDevice = null;
        }

        if (targetDevice != null) {
          try {
            await PrintThermal.bluetooth.connect(targetDevice);
            await PrintThermal.printReceipt(transaction);
          } catch (e) {
            // Fallback to manual selection if auto-connect fails
            _showDeviceSelection(transaction);
          }
        } else {
          // 3. Select Device
          _showDeviceSelection(transaction);
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Izin Bluetooth diperlukan untuk mencetak'),
        ),
      );
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
