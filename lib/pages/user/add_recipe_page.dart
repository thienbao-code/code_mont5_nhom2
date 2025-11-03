import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../models/recipe.dart';
import '../../db/recipe_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'my_recipes_page.dart';

class AddRecipePage extends StatefulWidget {
  final Recipe? recipe;
  const AddRecipePage({super.key, this.recipe});

  @override
  State<AddRecipePage> createState() => _AddRecipePageState();
}

class _AddRecipePageState extends State<AddRecipePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _stepsController = TextEditingController();

  String _selectedDifficulty = 'medium';
  bool _isLoading = false;
  File? _imageFile;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    if (widget.recipe != null) {
      _titleController.text = widget.recipe!.title;
      _descriptionController.text = widget.recipe!.description;
      _ingredientsController.text = widget.recipe!.ingredients;
      _stepsController.text = widget.recipe!.steps;
      _selectedDifficulty = widget.recipe!.difficulty;
      _imageUrl = widget.recipe!.imageUrl;
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
          _imageUrl = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi chọn ảnh: $e')));
    }
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    print('--- Bắt đầu lưu công thức ---');

    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('userEmail');
      final role = prefs.getString('role') ?? 'user'; // <--- thêm role
      final isAdmin =
          role == 'admin' || userEmail == 'admin@gmail.com'; // fallback

      print('userEmail: $userEmail');
      print('role: $role');

      if (userEmail == null || userEmail.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng đăng nhập trước khi thêm công thức.'),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Giữ ảnh cũ nếu người dùng không chọn ảnh mới
      String? imageUrl = _imageUrl;
      if (_imageFile != null) {
        imageUrl = _imageFile!.path; // giả lập lưu local
      }

      final recipe = Recipe(
        id: widget.recipe?.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        ingredients: _ingredientsController.text.trim(),
        steps: _stepsController.text.trim(),
        difficulty: _selectedDifficulty,
        nutritionTag: widget.recipe?.nutritionTag ?? '',
        status: isAdmin ? 'approved' : (widget.recipe?.status ?? 'pending'),
        createdBy: userEmail,
        imageUrl: imageUrl,
      );

      if (widget.recipe != null) {
        print('Cập nhật công thức ID: ${widget.recipe!.id}');
        await RecipeDatabase.instance.updateRecipe(recipe);
      } else {
        print('Thêm công thức mới');
        await RecipeDatabase.instance.insertRecipe(recipe);
      }

      if (!mounted) return;

      // Thông báo thành công
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Thành công'),
          content: Text(
            widget.recipe != null
                ? 'Công thức đã được cập nhật thành công!'
                : (isAdmin
                      ? 'Công thức đã được đăng thành công!'
                      : 'Công thức của bạn đã được gửi để duyệt!'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      await Future.delayed(const Duration(milliseconds: 200));

      if (Navigator.canPop(context)) {
        Navigator.of(context).pop(true);
        print('✅ Đã quay lại Món của bạn');
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MyRecipesPage()),
        );
      }
    } catch (e, stack) {
      debugPrint('🔥 Lỗi khi lưu công thức: $e');
      debugPrintStack(stackTrace: stack);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi lưu công thức: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
      print('--- Kết thúc lưu công thức ---');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.recipe != null ? 'Chỉnh sửa món ăn' : 'Thêm món mới',
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  image: _imageFile != null
                      ? DecorationImage(
                          image: FileImage(_imageFile!),
                          fit: BoxFit.cover,
                        )
                      : (_imageUrl != null
                            ? DecorationImage(
                                image: NetworkImage(_imageUrl!),
                                fit: BoxFit.cover,
                              )
                            : null),
                ),
                child: _imageFile == null && _imageUrl == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Thêm ảnh món ăn',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Tên món ăn',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.restaurant_menu),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Vui lòng nhập tên món ăn'
                  : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Mô tả',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
              validator: (v) => (v == null || v.trim().length < 10)
                  ? 'Mô tả quá ngắn (≥ 10 ký tự)'
                  : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _ingredientsController,
              decoration: const InputDecoration(
                labelText: 'Nguyên liệu',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.list_alt),
                helperText: 'Mỗi nguyên liệu một dòng',
              ),
              maxLines: 5,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Vui lòng nhập nguyên liệu';
                }
                final lines = v
                    .split('\n')
                    .where((e) => e.trim().isNotEmpty)
                    .toList();
                if (lines.length < 2) return 'Cần ít nhất 2 nguyên liệu';
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _stepsController,
              decoration: const InputDecoration(
                labelText: 'Các bước thực hiện',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.receipt_long),
                helperText: 'Mỗi bước một dòng',
              ),
              maxLines: 8,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Vui lòng nhập các bước';
                }
                final steps = v
                    .split('\n')
                    .where((e) => e.trim().isNotEmpty)
                    .toList();
                if (steps.length < 2) return 'Cần ít nhất 2 bước';
                return null;
              },
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedDifficulty,
              decoration: const InputDecoration(
                labelText: 'Độ khó',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.timer),
              ),
              items: const [
                DropdownMenuItem(value: 'easy', child: Text('Dễ')),
                DropdownMenuItem(value: 'medium', child: Text('Trung bình')),
                DropdownMenuItem(value: 'hard', child: Text('Khó')),
              ],
              onChanged: (v) => setState(() => _selectedDifficulty = v!),
            ),
            const SizedBox(height: 32),

            FilledButton.icon(
              onPressed: _isLoading ? null : _saveRecipe,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(
                widget.recipe != null ? 'Cập nhật món' : 'Gửi món mới',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _ingredientsController.dispose();
    _stepsController.dispose();
    super.dispose();
  }
}
