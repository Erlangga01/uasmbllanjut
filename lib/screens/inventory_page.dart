import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../providers/app_provider.dart';
import '../models/material_model.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().fetchMaterials();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const FaIcon(FontAwesomeIcons.warehouse, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  const Text(
                    'Inventaris Bahan Baku',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Table
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4), // Slightly less rounded to match simple table
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 2),
                  ],
                ),
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF9FAFB), // gray-50
                        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                      ),
                      child: Row(
                        children: const [
                          Expanded(flex: 3, child: Text('Nama Bahan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87))),
                          Expanded(flex: 1, child: Text('Stok', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87))),
                          Expanded(flex: 1, child: Text('Unit', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87))),
                        ],
                      ),
                    ),
                    
                    if (provider.isLoading)
                      const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
                    else if (provider.errorMessage != null)
                      Padding(padding: const EdgeInsets.all(20), child: Center(child: Text(provider.errorMessage!, style: const TextStyle(color: Colors.red))))
                    else if (provider.materials.isEmpty)
                       const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('Tidak ada data bahan baku')))
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: provider.materials.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                        itemBuilder: (context, index) {
                          final material = provider.materials[index];
                          
                          // Convert stock to string with simplistic formatting (remove .0 if integer)
                          String stockStr = material.stock % 1 == 0 ? material.stock.toInt().toString() : material.stock.toString();

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3, 
                                  child: Text(material.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF15803D), // green-700
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        stockStr,
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ),
                                const Expanded(
                                  flex: 1,
                                  child: Text(
                                    'Pcs', // Default, logic to get unit should optionally be in model
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.black54, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Menampilkan ${provider.materials.length} jenis bahan baku',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
