class Recipe {
  final int? id;
  final String title;
  final String description;
  final String ingredients;
  final String steps;
  final String? imageUrl; // Hình ảnh món ăn
  final String difficulty; // easy / medium / hard
  final String nutritionTag; // bổ máu, giảm mỡ, bổ não,...
  final String?
  createdBy; // 🔹 Người tạo công thức (dành cho phân quyền sau này)
  final String status; // 'pending' hoặc 'approved'

  Recipe({
    this.id,
    required this.title,
    required this.description,
    required this.ingredients,
    required this.steps,
    this.imageUrl,
    required this.difficulty,
    required this.nutritionTag,
    this.createdBy, // có thể là email hoặc id user
    this.status = 'pending',
  });

  // 🟢 Chuyển đối tượng -> Map (để lưu DB)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'ingredients': ingredients,
      'steps': steps,
      'imageUrl': imageUrl,
      'difficulty': difficulty,
      'nutritionTag': nutritionTag,
      'createdBy': createdBy,
      'status': status,
    };
  }

  static Recipe fromMap(Map<String, dynamic> map) {
    return Recipe(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      ingredients: map['ingredients'],
      steps: map['steps'],
      imageUrl: map['imageUrl'],
      difficulty: map['difficulty'],
      nutritionTag: map['nutritionTag'],
      createdBy: map['createdBy'],
      status: map['status'] ?? 'pending',
    );
  }

  // 🟣 Getter hiển thị độ khó bằng tiếng Việt
  String get difficultyVi {
    switch (difficulty) {
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
}
