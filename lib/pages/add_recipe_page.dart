import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/recipe_database.dart';
import '../models/recipe.dart';

class AddRecipePage extends StatefulWidget {
  final Recipe? recipe; // nếu có -> sửa, nếu null -> thêm

  const AddRecipePage({super.key, this.recipe});

  @override
  State<AddRecipePage> createState() => _AddRecipePageState();
}

class _AddRecipePageState extends State<AddRecipePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _stepsController = TextEditingController();
  final _imageController = TextEditingController();

  String _selectedDifficulty = 'medium';
  String _selectedNutrition = 'khác';
  bool _isSaving = false;

  bool get isEditing => widget.recipe != null;

  List<String> _parseItems(String input) {
    final s = input.trim();
    if (s.isEmpty) return [];
    return s
        .split(RegExp(r'\r?\n|,|\||;')) // xuống dòng, dấu phẩy, | hoặc ;
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final r = widget.recipe!;
      _titleController.text = r.title;
      // r.description is non-nullable according to analyzer -> use directly
      _descController.text = r.description;
      // Nếu model lưu ingredients/steps là List thì chuyển về multi-line,
      // nếu là String thì toString() (no null-aware operators)
      if (r.ingredients is List) {
        _ingredientsController.text = (r.ingredients as List).join('\n');
      } else {
        _ingredientsController.text = r.ingredients.toString();
      }
      if (r.steps is List) {
        _stepsController.text = (r.steps as List).join('\n');
      } else {
        _stepsController.text = r.steps.toString();
      }
      // imageUrl may be nullable -> keep fallback
      _imageController.text = r.imageUrl ?? '';
      // difficulty / nutritionTag are non-nullable per analyzer -> use directly
      _selectedDifficulty = r.difficulty;
      _selectedNutrition = r.nutritionTag;
    }
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('userEmail');

      // Chuyển sang String: mỗi item trên 1 dòng
      final ingredientsString = _parseItems(
        _ingredientsController.text,
      ).join('\n');
      final stepsString = _parseItems(_stepsController.text).join('\n');

      final recipe = Recipe(
        id: widget.recipe?.id,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        ingredients: ingredientsString,
        steps: stepsString,
        imageUrl: _imageController.text.trim().isEmpty
            ? null
            : _imageController.text.trim(),
        difficulty: _selectedDifficulty,
        nutritionTag: _selectedNutrition,
        createdBy: widget.recipe?.createdBy ?? (userEmail ?? 'unknown'),
        status: widget.recipe?.status ?? 'pending',
      );

      if (isEditing) {
        await RecipeDatabase.instance.updateRecipe(recipe);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cập nhật công thức thành công')),
          );
          Navigator.pop(context, true);
        }
      } else {
        await RecipeDatabase.instance.insertRecipe(recipe);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã gửi công thức để chờ duyệt')),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _ingredientsController.dispose();
    _stepsController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Sửa công thức' : 'Thêm công thức mới'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Tên món ăn'),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Vui lòng nhập tên món ăn'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Mô tả món ăn',
                  hintText: 'Viết ngắn gọn, tối thiểu 10 ký tự',
                ),
                maxLines: 3,
                validator: (v) {
                  if (v == null || v.trim().isEmpty)
                    return 'Vui lòng nhập mô tả';
                  if (v.trim().length < 10) return 'Mô tả quá ngắn';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _ingredientsController,
                decoration: const InputDecoration(
                  labelText:
                      'Nguyên liệu (mỗi dòng 1 nguyên liệu hoặc ngăn cách bằng , ; | )',
                ),
                maxLines: 4,
                validator: (v) {
                  final items = _parseItems(v ?? '');
                  if (items.isEmpty)
                    return 'Vui lòng nhập ít nhất 1 nguyên liệu';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _stepsController,
                decoration: const InputDecoration(
                  labelText: 'Các bước nấu (mỗi bước một dòng)',
                ),
                maxLines: 6,
                validator: (v) {
                  final steps = _parseItems(v ?? '');
                  if (steps.isEmpty) return 'Vui lòng nhập ít nhất 1 bước';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _imageController,
                decoration: const InputDecoration(
                  labelText: 'URL hình ảnh (tùy chọn)',
                  hintText: 'https://...',
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedDifficulty,
                decoration: const InputDecoration(labelText: 'Mức độ khó'),
                items: const [
                  DropdownMenuItem(value: 'easy', child: Text('Dễ')),
                  DropdownMenuItem(value: 'medium', child: Text('Trung bình')),
                  DropdownMenuItem(value: 'hard', child: Text('Khó')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedDifficulty = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedNutrition,
                decoration: const InputDecoration(labelText: 'Nhóm dinh dưỡng'),
                items: const [
                  DropdownMenuItem(value: 'bổ máu', child: Text('Bổ máu')),
                  DropdownMenuItem(
                    value: 'giảm mỡ',
                    child: Text('Giảm mỡ thừa'),
                  ),
                  DropdownMenuItem(value: 'bổ não', child: Text('Bổ não')),
                  DropdownMenuItem(value: 'bổ gan', child: Text('Bổ gan')),
                  DropdownMenuItem(value: 'bổ thận', child: Text('Bổ thận')),
                  DropdownMenuItem(value: 'bổ xương', child: Text('Bổ xương')),
                  DropdownMenuItem(value: 'khác', child: Text('Khác')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedNutrition = value);
                  }
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveRecipe,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  isEditing ? 'Cập nhật công thức' : 'Lưu công thức mới',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
