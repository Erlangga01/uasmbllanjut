import 'dart:typed_data';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
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
  static Future<void> printReceipt(TransactionResponse transaction) async {
    // Check if connected
    if ((await bluetooth.isConnected) == true) {
      await _print(transaction);
    } else {
      print("Printer not connected");
      // UI should handle connection prompts
    }
  }

  static Future<void> _print(TransactionResponse transaction) async {
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
    bytes += generator.text('No    : ${transaction.id}');
    bytes += generator.text(
      'Kasir : Admin',
    ); // Static as requested/implied or default
    bytes += generator.text(
      'Tgl   : ${transaction.transactionDate} ${DateFormat('HH:mm').format(transaction.createdAt)}',
    );
    bytes += generator.hr();

    // 3. Items
    for (var item in transaction.items) {
      // Item Name
      bytes += generator.text(
        item.productName,
        styles: const PosStyles(bold: true),
      );

      // Qty x Price ... Total
      double totalItemPrice = item.quantity * item.price;
      bytes += generator.row([
        PosColumn(
          text: '${item.quantity} x ${_formatCurrency(item.price)}',
          width: 8,
        ),
        PosColumn(
          text: _formatCurrency(totalItemPrice),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }
    bytes += generator.hr();

    // 4. Totals
    bytes += generator.row([
      PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
        text: _formatCurrency(transaction.totalAmount),
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);

    // Assuming immediate payment for now as fields are missing
    bytes += generator.row([
      PosColumn(text: 'TUNAI', width: 6),
      PosColumn(
        text: _formatCurrency(transaction.totalAmount),
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    bytes += generator.row([
      PosColumn(text: 'KEMBALI', width: 6),
      PosColumn(
        text: _formatCurrency(0),
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

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
    } catch (e) {
      print("Error printing: $e");
    }
  }
}
