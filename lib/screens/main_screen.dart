import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'input_page.dart';
import 'sales_page.dart';
import 'inventory_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const InputPage(),
    const SalesPage(),
    const InventoryPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // App Bar is handled inside individual pages or here? Mockup has a common header.
      // The mockup shows a header that stays, but content changes.
      // However code structure in mockup: <div id="content-area"> which changes.
      // The Header is OUTSIDE content area. So we can put AppBar here.
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFF2563EB), // blue-600
        foregroundColor: Colors.white,
        elevation: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: const [
             Text(
              'Axl Elektronik',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
             Text(
              'Produsen Sound System & Komponen',
              style: TextStyle(fontSize: 12, color: Color(0xFFDBEAFE)), // blue-100
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))), // gray-200
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF2563EB), // blue-600
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.cashRegister),
              label: 'Kasir',
            ),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.chartPie),
              label: 'Laporan Jual',
            ),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.toolbox),
              label: 'Stok Bahan',
            ),
          ],
        ),
      ),
    );
  }
}
