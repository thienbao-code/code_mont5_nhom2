import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/add_recipe_page.dart';
import 'pages/recipe_detail.dart';
import 'user/login_page.dart';
import 'user/register_page.dart';
import 'db/recipe_database.dart';
import 'models/recipe.dart';
//import 'models/user.dart';
import 'pages/admin/admin_home_page.dart';
import 'pages/user/user_home_page.dart';

// Global navigator key (nếu cần)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo DB trước khi chạy app
  await RecipeDatabase.instance.database;

  // Lấy thông tin đăng nhập đã lưu (nếu có) để chọn initialRoute
  final prefs = await SharedPreferences.getInstance();
  final savedEmail = prefs.getString('userEmail');
  final savedPass = prefs.getString('userPassword');

  String initialRoute = '/login';
  if (savedEmail != null && savedPass != null) {
    try {
      final user = await RecipeDatabase.instance.getUser(savedEmail, savedPass);
      if (user != null) {
        initialRoute = user.role == 'admin' ? '/admin' : '/user';
      }
    } catch (_) {
      initialRoute = '/login';
    }
  }

  runApp(RecipeApp(initialRoute: initialRoute));
}

class RecipeApp extends StatelessWidget {
  final String initialRoute;
  const RecipeApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Recipe App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: initialRoute,
      routes: {
        // Login/Register are non-const constructors in your project -> DO NOT use const
        '/login': (context) => LoginPage(),
        '/register': (context) => RegisterPage(),
        // User/Admin home pages are const-capable
        '/user': (context) => const UserHomePage(),
        '/admin': (context) => const AdminHomePage(),
        // Add page: remove const if ctor is not const
        '/add': (context) => AddRecipePage(),
        // alias
        '/home': (context) => const UserHomePage(),
      },
      // onGenerateRoute cho trang detail (truyền Recipe qua arguments)
      onGenerateRoute: (settings) {
        if (settings.name == '/recipe_detail') {
          final args = settings.arguments;
          if (args is Recipe) {
            return MaterialPageRoute(
              builder: (_) => RecipeDetailPage(recipe: args),
            );
          }
        }
        return null;
      },
    );
  }
}

/* ---------- RecipeListPage (UI chính) ---------- */
class RecipeListPage extends StatefulWidget {
  const RecipeListPage({super.key});

  @override
  State<RecipeListPage> createState() => _RecipeListPageState();
}

class _RecipeListPageState extends State<RecipeListPage> {
  // currentUser được load từ SharedPreferences/DB
  dynamic currentUser;
  List<Recipe> _recipes = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String selectedDifficulty = 'Tất cả';

  final List<Map<String, String>> trendingKeywords = [
    {
      'text': 'thực đơn mỗi ngày',
      'image':
          'https://giadungducsaigon.vn/wp-content/uploads/2021/12/mon-an-ngon-moi-ngay-de-dang-thuc-hien.jpg',
    },
    {
      'text': 'thịt',
      'image': 'https://tse1.mm.bing.net/th/id/OIP.HY-OOeB5N-dhJTQB01VHSwHaE9',
    },
    {
      'text': 'trứng',
      'image': 'https://tiki.vn/blog/wp-content/uploads/2023/07/thumb-18.jpg',
    },
    {
      'text': 'sườn',
      'image':
          'https://bepmina.vn/wp-content/uploads/2023/04/cach-lam-suon-xao-chua-ngot-mien-bac.jpeg',
    },
    {
      'text': 'nấm đùi gà',
      'image': 'https://tse1.mm.bing.net/th/id/OIP.DROLkyyb78YMgjIJPkfC2AHaEL',
    },
    {
      'text': 'bánh',
      'image':
          'https://www.cadenadial.com/wp-content/uploads/2022/10/Panes-e1664955910226-1024x578.jpg',
    },
    {
      'text': 'cá',
      'image': 'https://tse4.mm.bing.net/th/id/OIP.5F7slvD_e3mH4PSESPVbYAHaEK',
    },
  ];

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _loadRecipes();
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail');
    final pass = prefs.getString('userPassword');
    if (email == null || pass == null) {
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
      return;
    }
    final user = await RecipeDatabase.instance.getUser(email, pass);
    if (mounted) setState(() => currentUser = user);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get canManageRecipes => currentUser?.role == 'admin';

  Future<void> _loadRecipes() async {
    setState(() => _isLoading = true);
    try {
      final data = await RecipeDatabase.instance.getAllRecipes();
      if (mounted)
        setState(() {
          _recipes = data;
          _isLoading = false;
        });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi tải dữ liệu: $e')));
      }
    }
  }

  Future<void> _searchRecipes(String keyword) async {
    if (keyword.isEmpty) {
      _loadRecipes();
      return;
    }
    setState(() => _isLoading = true);
    try {
      final data = await RecipeDatabase.instance.searchRecipes(keyword);
      if (mounted)
        setState(() {
          _recipes = data;
          _isLoading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Recipe> _filterRecipes(List<Recipe> list) {
    return list.where((recipe) {
      return selectedDifficulty == 'Tất cả' ||
          recipe.difficulty == _convertToEnglishDifficulty(selectedDifficulty);
    }).toList();
  }

  String _convertToEnglishDifficulty(String vietnamese) {
    switch (vietnamese) {
      case 'Dễ':
        return 'easy';
      case 'Trung bình':
        return 'medium';
      case 'Khó':
        return 'hard';
      default:
        return vietnamese.toLowerCase();
    }
  }

  String _convertToVietnameseDifficulty(String english) {
    switch (english) {
      case 'easy':
        return 'Dễ';
      case 'medium':
        return 'Trung bình';
      case 'hard':
        return 'Khó';
      default:
        return 'Không rõ';
    }
  }

  void _addRecipe() async {
    // user thường add thì route '/add' (AddRecipePage) trả về true khi lưu xong
    final res = await Navigator.pushNamed(context, '/add');
    if (res == true && mounted) _loadRecipes();
  }

  void _editRecipe(Recipe recipe) async {
    if (!canManageRecipes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn không có quyền sửa công thức')),
      );
      return;
    }
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddRecipePage(recipe: recipe)),
    );
    if (updated == true && mounted) _loadRecipes();
  }

  Future<void> _handleDelete(Recipe recipe) async {
    if (!canManageRecipes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn không có quyền xóa công thức')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa công thức "${recipe.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await RecipeDatabase.instance.deleteRecipe(recipe.id!);
        if (mounted) {
          await _loadRecipes();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Đã xóa công thức')));
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Lỗi khi xóa: $e')));
      }
    }
  }

  void _searchFromKeyword(String keyword) {
    _searchController.text = keyword;
    _searchRecipes(keyword);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filterRecipes(_recipes);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Công thức nấu ăn',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecipes,
            tooltip: 'Làm mới',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('userEmail');
              await prefs.remove('userPassword');
              if (mounted) Navigator.of(context).pushReplacementNamed('/login');
            },
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Tìm kiếm công thức...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: _searchRecipes,
                  ),
                ),
                SizedBox(
                  height: 110,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    scrollDirection: Axis.horizontal,
                    itemCount: trendingKeywords.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final item = trendingKeywords[index];
                      return InkWell(
                        onTap: () => _searchFromKeyword(item['text']!),
                        child: Container(
                          width: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: NetworkImage(item['image']!),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.7),
                                ],
                              ),
                            ),
                            padding: const EdgeInsets.all(8),
                            alignment: Alignment.bottomLeft,
                            child: Text(
                              item['text']!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final recipe = filtered[index];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RecipeDetailPage(recipe: recipe),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  recipe.imageUrl != null &&
                                          recipe.imageUrl!.isNotEmpty
                                      ? Image.network(
                                          recipe.imageUrl!,
                                          width: double.infinity,
                                          height: 120,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _buildPlaceholderImage(),
                                        )
                                      : _buildPlaceholderImage(),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getDifficultyColor(
                                          recipe.difficulty,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _convertToVietnameseDifficulty(
                                          recipe.difficulty,
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        recipe.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Expanded(
                                        child: Text(
                                          recipe.description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (currentUser?.role == 'admin')
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 20,
                                        ),
                                        color: Colors.blue,
                                        onPressed: () => _editRecipe(recipe),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 20,
                                        ),
                                        color: Colors.red,
                                        onPressed: () => _handleDelete(recipe),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: currentUser?.role == 'admin'
          ? FloatingActionButton(
              onPressed: _addRecipe,
              child: const Icon(Icons.add),
              tooltip: 'Thêm công thức mới',
            )
          : null,
    );
  }

  Widget _buildPlaceholderImage() => Container(
    height: 120,
    color: Colors.grey[200],
    child: Center(
      child: Icon(Icons.restaurant, size: 48, color: Colors.grey[400]),
    ),
  );

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
