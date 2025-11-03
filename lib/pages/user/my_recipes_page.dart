import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/recipe.dart';
import '../../db/recipe_database.dart';
import '../recipe_detail.dart';
import '../add_recipe_page.dart';

class MyRecipesPage extends StatefulWidget {
  const MyRecipesPage({super.key});

  @override
  State<MyRecipesPage> createState() => _MyRecipesPageState();
}

class _MyRecipesPageState extends State<MyRecipesPage> {
  List<Recipe> _myRecipes = [];
  bool _isLoading = true;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _loadUserAndRecipes();
  }

  Future<void> _loadUserAndRecipes() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _userEmail = prefs.getString('userEmail');

      if (_userEmail == null) {
        // Nếu không có thông tin đăng nhập, chuyển về màn login
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
        return;
      }

      final recipes = await RecipeDatabase.instance.getUserRecipes(_userEmail!);
      if (!mounted) return;
      setState(() {
        _myRecipes = recipes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi tải công thức: $e')));
    }
  }

  Future<void> _deleteRecipe(Recipe recipe) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa công thức này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await RecipeDatabase.instance.deleteRecipe(recipe.id!);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã xóa công thức')));
        await _loadUserAndRecipes();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi xóa: $e')));
      }
    }
  }

  Future<void> _editRecipe(Recipe recipe) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddRecipePage(recipe: recipe)),
    );
    if (res == true && mounted) {
      await _loadUserAndRecipes();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã cập nhật công thức')));
    }
  }

  Widget _buildList(String status) {
    final filtered = _myRecipes.where((r) => r.status == status).toList();

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          status == 'pending'
              ? 'Không có công thức đang chờ duyệt'
              : 'Bạn chưa có công thức nào được duyệt',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUserAndRecipes,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final recipe = filtered[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RecipeDetailPage(recipe: recipe),
                ),
              ),
              leading: recipe.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        recipe.imageUrl!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.restaurant),
                      ),
                    )
                  : const Icon(Icons.restaurant),
              title: Text(recipe.title),
              subtitle: Text(
                status == 'pending' ? 'Đang chờ duyệt' : 'Đã được duyệt',
                style: TextStyle(
                  color: status == 'pending' ? Colors.orange : Colors.green,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (status == 'pending')
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      tooltip: 'Chỉnh sửa',
                      onPressed: () => _editRecipe(recipe),
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Xóa',
                    onPressed: () => _deleteRecipe(recipe),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Công thức của tôi'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadUserAndRecipes,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Chờ duyệt'),
              Tab(text: 'Đã duyệt'),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildList('pending'), _buildList('approved')],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final res = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddRecipePage()),
            );
            if (res == true && mounted) await _loadUserAndRecipes();
          },
          child: const Icon(Icons.add),
          tooltip: 'Thêm công thức mới',
        ),
      ),
    );
  }
}
