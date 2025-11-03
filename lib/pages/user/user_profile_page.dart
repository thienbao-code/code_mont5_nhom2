import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user.dart';
import '../../db/recipe_database.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  User? _currentUser;
  bool _isLoading = true;
  int _totalRecipes = 0;
  int _pendingRecipes = 0;
  int _approvedRecipes = 0;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('userEmail');
      final password = prefs.getString('userPassword');

      if (email != null && password != null) {
        final user = await RecipeDatabase.instance.getUser(email, password);
        if (user != null) {
          // Prefer database helper that returns counts (efficient)
          try {
            final counts = await RecipeDatabase.instance.getUserRecipeCounts(
              email,
            );
            _totalRecipes = counts['total'] ?? 0;
            _pendingRecipes = counts['pending'] ?? 0;
            _approvedRecipes = counts['approved'] ?? 0;
          } catch (_) {
            // fallback: load full list if counts helper not available
            final recipes = await RecipeDatabase.instance.getUserRecipes(email);
            _totalRecipes = recipes.length;
            _pendingRecipes = recipes
                .where((r) => r.status == 'pending')
                .length;
            _approvedRecipes = recipes
                .where((r) => r.status == 'approved')
                .length;
          }

          if (mounted) {
            setState(() {
              _currentUser = user;
              _isLoading = false;
            });
          }
          return;
        }
      }

      // Nếu không tìm thấy user -> logout
      if (mounted) {
        setState(() => _isLoading = false);
        await _forceLogout();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _forceLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userEmail');
    await prefs.remove('userPassword');
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _forceLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài khoản của tôi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentUser == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 12),
                  const Text('Không tìm thấy thông tin người dùng'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _forceLogout,
                    child: const Text('Quay về đăng nhập'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadUserProfile,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 8),
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.person, size: 50, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _currentUser!.email,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vai trò: ${_currentUser!.role}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _buildStatCard(
                    title: 'Tổng số công thức',
                    value: _totalRecipes,
                    icon: Icons.restaurant_menu,
                  ),
                  const SizedBox(height: 12),
                  _buildStatCard(
                    title: 'Đang chờ duyệt',
                    value: _pendingRecipes,
                    icon: Icons.pending_actions,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  _buildStatCard(
                    title: 'Đã được duyệt',
                    value: _approvedRecipes,
                    icon: Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/home'),
                    icon: const Icon(Icons.home),
                    label: const Text('Về trang chủ'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Đăng xuất'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required int value,
    required IconData icon,
    Color? color,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color ?? Theme.of(context).primaryColor),
        title: Text(title),
        trailing: Text(
          value.toString(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: color ?? Theme.of(context).primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
