import 'dart:typed_data';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/transaction.dart';

class PrintThermal {
  static final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  // Format currency
  static String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    ).format(amount);
  }

  // Main print method
  static Future<bool> printReceipt(TransactionResponse transaction) async {
    // 0. Ensure Permissions
    if (await Permission.bluetoothConnect.request().isGranted &&
        await Permission.bluetoothScan.request().isGranted &&
        await Permission.location.request().isGranted) {
      // 0.5 Check if Bluetooth is On
      if ((await bluetooth.isOn) != true) {
        print("Bluetooth is OFF");
        return false;
      }

      // 1. Check if connected
      if ((await bluetooth.isConnected) != true) {
        // 2. Try to auto-connect
        bool connected = await _tryAutoConnect();
        if (!connected) {
          print("Printer not connected and auto-connect failed");
          return false;
        }
      }

      // 3. Print
      return await _print(transaction);
    } else {
      print("Permissions not granted");
      return false;
    }
  }

  static Future<bool> _tryAutoConnect() async {
    try {
      print("PrintThermal: Getting bonded devices...");
      List<BluetoothDevice> bondedDevices = await bluetooth.getBondedDevices();
      print("PrintThermal: Found ${bondedDevices.length} bonded devices.");

      BluetoothDevice? targetDevice;
      // Find "Accessgo" or "RPP02N" or specific MAC
      try {
        targetDevice = bondedDevices.firstWhere((d) {
          print("PrintThermal: Checking device '${d.name}' (${d.address})");
          final name = (d.name ?? '').toLowerCase();
          final address = (d.address ?? '').toUpperCase();
          return name.contains('acces') ||
              name.contains('rpp02n') ||
              address == 'DC:0D:51:FF:DB:06';
        });
      } catch (e) {
        // Not found
        print(
          "PrintThermal: No compatible printer (Accessgo/RPP02N) found in bonded devices.",
        );
        return false;
      }

      // Found device
      print(
        "PrintThermal: Found target device: ${targetDevice.name} (${targetDevice.address}). Connecting...",
      );
      try {
        await bluetooth.connect(targetDevice);
      } catch (e) {
        print("PrintThermal: Exception during connect: $e");
        return false;
      }

      // Wait a bit for connection to stabilize
      await Future.delayed(const Duration(milliseconds: 500));
      bool isConnected = (await bluetooth.isConnected) == true;
      print("PrintThermal: Connection status after attempt: $isConnected");
      return isConnected;
    } catch (e) {
      print("PrintThermal: Error auto-connecting: $e");
    }
    return false;
  }

  static Future<bool> _print(TransactionResponse transaction) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    // 1. Header
    bytes += generator.text(
      'axl elektronik',
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: true,
      ),
    );
    bytes += generator.text(
      'ketapang ngusikan jombang',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'no telp +6285231806510',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.hr();

    // 2. Transaction Info
    bytes += generator.text('No       : ${transaction.id}');
    bytes += generator.text(
      'Tanggal  : ${transaction.transactionDate} ${DateFormat('HH:mm').format(transaction.createdAt)}',
    );
    bytes += generator.text('Pelanggan: ${transaction.customerName}');
    bytes += generator.text('Kasir    : Admin');
    bytes += generator.hr();

    // 3. Items
    double subtotal = 0.0;

    for (var item in transaction.items) {
      // Item Name
      bytes += generator.text(
        item.productName,
        styles: const PosStyles(bold: true),
      );

      // Calculations
      // Note: item.totalPrice from API generally includes the per-item discount.
      // Let's verify: In previous step CartItem, total = (price * qty) * (1 - disc/100).
      // So item.totalPrice should be the discounted total.
      // item.price is the unit price (original).
      // Let's print:
      // Qty x Price ...
      // (Disc xx%) ... Total

      double originalLineTotal = item.quantity * item.price;
      subtotal += item.totalPrice;

      // Line 1: Qty x Unit Price | Original Total (if no discount) or just Unit Price info
      bytes += generator.row([
        PosColumn(
          text: '${item.quantity} x ${_formatCurrency(item.price)}',
          width: 8,
        ),
        PosColumn(
          text: _formatCurrency(
            originalLineTotal,
          ), // Show original total before disc
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      // Line 2: If there is discount
      if (item.discountPercent > 0) {
        bytes += generator.row([
          PosColumn(
            text: 'Desc ${item.discountPercent.toStringAsFixed(0)}%',
            width: 8,
            styles: const PosStyles(align: PosAlign.left),
          ),
          PosColumn(
            text: '-${_formatCurrency(originalLineTotal - item.totalPrice)}',
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
        // Maybe an extra line showing final "Clean" item total?
        // Usually receipts just show the final line total at the right if indented,
        // OR the right column IS the final total.
        // Let's adjust:
        // Qty x Price         Total (Final)
        // (Disc X%)
        // Let's re-do standard layout:

        // Option B (Clearer):
        // Item Name
        // 2 x 50.000 (Disc 10%)    90.000

        // Or if standard:
        // 2 x 50.000              100.000
        // Disc 10%                -10.000
        // -------------------------------
      }
    }
    bytes += generator.hr();

    // 4. Totals
    // Calculate VAT Amount
    // transaction.totalAmount is the Grand Total (Subtotal + VAT).
    // transaction.tax is the VAT Percent (e.g., 10).
    // So GrandTotal = Subtotal + (Subtotal * Tax/100) = Subtotal * (1 + Tax/100)
    // Subtotal = GrandTotal / (1 + Tax/100)
    // But wait, in the input page: _grandTotal = _cartTotal + _vatAmount.
    // _cartTotal IS the subtotal (sum of item totals).
    // So if the API stored grand_total correctly, we can reverse calc or use detailed item sum.

    // Let's use the subtotal summed from items above as the source of truth for "Subtotal".
    // And if `transaction.tax` is percent, we calc VAT amount from subtotal.
    // Finally verify if (Subtotal + VAT) matches transaction.totalAmount.

    double vatAmount = subtotal * (transaction.tax / 100);
    double calculatedGrandTotal = subtotal + vatAmount;

    // Subtotal
    bytes += generator.row([
      PosColumn(text: 'Subtotal', width: 6),
      PosColumn(
        text: _formatCurrency(subtotal),
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    // VAT
    if (transaction.tax > 0) {
      bytes += generator.row([
        PosColumn(
          text: 'PPN (${transaction.tax.toStringAsFixed(0)}%)',
          width: 6,
        ),
        PosColumn(
          text: _formatCurrency(vatAmount),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    // Separator?
    // bytes += generator.hr(); // Maybe too much lines

    // Grand Total
    bytes += generator.row([
      PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
        text: _formatCurrency(
          calculatedGrandTotal,
        ), // Use calculated to ensure consistency or transaction.totalAmount
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);

    bytes += generator.feed(1);

    // Tunai / Payment (Assuming Cash = Total for now as specific Payment details aren't in response yet)
    // bytes += generator.row([
    //   PosColumn(text: 'TUNAI', width: 6),
    //   PosColumn(
    //     text: _formatCurrency(calculatedGrandTotal),
    //     width: 6,
    //     styles: const PosStyles(align: PosAlign.right),
    //   ),
    // ]);

    // bytes += generator.row([
    //   PosColumn(text: 'KEMBALI', width: 6),
    //   PosColumn(
    //     text: _formatCurrency(0),
    //     width: 6,
    //     styles: const PosStyles(align: PosAlign.right),
    //   ),
    // ]);

    bytes += generator.hr();

    // 5. Footer
    bytes += generator.text(
      'Terima Kasih',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.text(
      'Barang yang sudah dicetakan\ntidak dapat dikembalikan',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.feed(2);
    // bytes += generator.cut(); // Some small printers don't support cut, safe to omit or keep if standard

    try {
      await bluetooth.writeBytes(Uint8List.fromList(bytes));
      return true;
    } catch (e) {
      print("Error printing: $e");
      return false;
    }
  }
}
