import 'package:flutter/material.dart';

import 'home_page.dart';
import 'add_recipe_page.dart';
import 'my_recipes_page.dart';
import 'user_profile_page.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  int _selectedIndex = 0; // 👈 thêm biến này

  final List<Widget> _pages = [
    const HomePage(), // Trang chủ người dùng
    const AddRecipePage(), // Thêm công thức mới
    const MyRecipesPage(), // Công thức của tôi
    const UserProfilePage(), // Trang cá nhân
  ];

  // Hàm xử lý chuyển tab
  void _onTabTapped(int index) async {
    if (index == 1) {
      // Nếu người dùng nhấn "Thêm món"
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AddRecipePage()),
      );
      if (result == true) {
        // Sau khi thêm món xong → chuyển sang "Món của tôi"
        setState(() => _selectedIndex = 2);
      }
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.purple,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Trang chủ'),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Thêm món',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Món của tôi'),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'Tài khoản',
          ),
        ],
        onTap: _onTabTapped,
      ),
    );
  }
}
