import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../providers/app_provider.dart';
import '../models/transaction.dart';
import 'dart:async';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  String _currentTime = '';

  @override
  void initState() {
    super.initState();
    _updateTime();
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AppProvider>().fetchTransactions();
      if (mounted) _updateTime();
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _currentTime = DateFormat('HH:mm:ss').format(now);
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        // Calculate Summary Stats
        double totalOmzet = provider.transactions.fold(0, (sum, item) => sum + item.totalAmount);
        int totalTransactions = provider.transactions.length;

        return RefreshIndicator(
          onRefresh: () async {
            await provider.fetchTransactions();
            if (context.mounted) _updateTime();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Summary Card (Matching Laravel "bg-primary")
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0d6efd), Color(0xFF0a58ca)], // Bootstrap primary colors
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Background Icon
                      Positioned(
                        right: -10,
                        top: -10,
                        child: FaIcon(
                          FontAwesomeIcons.chartLine,
                          size: 120,
                          color: Colors.white.withOpacity(0.15),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TOTAL OMZET',
                              style: TextStyle(
                                fontSize: 12,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(totalOmzet),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                _buildSummaryItem('Transaksi', '${totalTransactions}x'),
                                const SizedBox(width: 32),
                                _buildSummaryItem('Terakhir Update', '$_currentTime WIB'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 2. Header "Riwayat Penjualan"
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        FaIcon(FontAwesomeIcons.clockRotateLeft, size: 18, color: Colors.grey),
                        SizedBox(width: 8),
                        Text(
                          'Riwayat Penjualan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54, // "text-secondary"
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),

                // 3. Status/Error Handling
                if (provider.isLoading)
                   const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                else if (provider.errorMessage != null)
                   Center(
                     child: Padding(
                       padding: const EdgeInsets.all(20),
                       child: Column(
                         children: [
                           const Text('Gagal memuat data', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                           Text(provider.errorMessage!, style: const TextStyle(color: Colors.black54), textAlign: TextAlign.center),
                           TextButton(onPressed: () => provider.fetchTransactions(), child: const Text("Coba Lagi"))
                         ],
                       ),
                     ),
                   )
                else if (provider.transactions.isEmpty)
                   _buildEmptyState()
                else
                   // 4. Transaction List (Matching Laravel Loop)
                   ListView.separated(
                     shrinkWrap: true,
                     physics: const NeverScrollableScrollPhysics(),
                     itemCount: provider.transactions.length,
                     separatorBuilder: (context, index) => const SizedBox(height: 16),
                     itemBuilder: (context, index) {
                       final transaction = provider.transactions[index];
                       return _buildTransactionCard(transaction);
                     },
                   ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildTransactionCard(TransactionResponse transaction) {
    final currencyFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
        ],
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              color: const Color(0xFF198754),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Date & Customer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const FaIcon(FontAwesomeIcons.solidCalendar, size: 12, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  transaction.transactionDate,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6),
                                  child: Text('•', style: TextStyle(color: Colors.grey)),
                                ),
                                const FaIcon(FontAwesomeIcons.solidUser, size: 12, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  transaction.customerName,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Items List Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        children: transaction.items.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: const TextStyle(color: Colors.black87, fontSize: 13),
                                      children: [
                                        TextSpan(text: item.productName),
                                        const TextSpan(text: '  '),
                                        TextSpan(
                                          text: 'x${item.quantity}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Text(
                                  currencyFmt.format(item.price * item.quantity),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Footer: Lunas & Total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Spacer(),
                      ],
                    ),
                    
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1E7DD),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFBADBCC)),
                        ),
                        child: const Text(
                          'LUNAS',
                          style: TextStyle(color: Color(0xFF0F5132), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    
                    const Divider(height: 24),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Bayar', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(
                          currencyFmt.format(transaction.totalAmount),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: const [
            FaIcon(FontAwesomeIcons.basketShopping, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('Belum ada data penjualan', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
