import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../models/recipe.dart';
import '../models/user.dart';

class RecipeDatabase {
  static final RecipeDatabase instance = RecipeDatabase._init();
  static Database? _database;

  RecipeDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('recipes.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 7,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onOpen: _onOpen,
    );
  }

  Future<void> _onOpen(Database db) async {
    await _ensureSchema(db);
    await _ensureAdminExists(db); // đảm bảo admin có mặt
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE recipes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        ingredients TEXT NOT NULL,
        steps TEXT NOT NULL,
        imageUrl TEXT,
        difficulty TEXT DEFAULT 'medium',
        nutritionTag TEXT DEFAULT '',
        createdBy TEXT,
        status TEXT DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        role TEXT NOT NULL
      )
    ''');

    await _ensureAdminExists(db);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    await _ensureSchema(db);
    await _ensureAdminExists(db);
  }

  Future<void> _ensureAdminExists(Database db) async {
    try {
      final res = await db.query(
        'users',
        where: 'email = ?',
        whereArgs: ['admin@gmail.com'],
      );
      if (res.isEmpty) {
        await db.insert('users', {
          'email': 'admin@gmail.com',
          'password': 'admin123',
          'role': 'admin',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        debugPrint('✅ Default admin created: admin@gmail.com / admin123');
      } else {
        debugPrint('ℹ️ Admin already exists');
      }
    } catch (e) {
      debugPrint('❌ ensureAdminExists error: $e');
    }
  }

  // Đảm bảo schema: thêm cột nếu thiếu (chạy trên onOpen/onUpgrade)
  Future<void> _ensureSchema(Database db) async {
    final recipeColumns = await db.rawQuery("PRAGMA table_info('recipes')");
    final colNames = recipeColumns.map((c) => c['name']?.toString()).toSet();

    if (!colNames.contains('createdBy')) {
      try {
        await db.execute("ALTER TABLE recipes ADD COLUMN createdBy TEXT");
      } catch (e) {
        debugPrint('Failed to add column createdBy: $e');
      }
    }

    if (!colNames.contains('status')) {
      try {
        // SQLite không hỗ trợ thêm DEFAULT + NOT NULL trong ALTER TABLE ở mọi trường hợp,
        // nên thêm cột TEXT rồi cập nhật giá trị mặc định nếu cần.
        await db.execute("ALTER TABLE recipes ADD COLUMN status TEXT");
        // set default value 'pending' cho các bản ghi hiện có
        await db.rawUpdate(
          "UPDATE recipes SET status = ? WHERE status IS NULL OR status = ''",
          ['pending'],
        );
      } catch (e) {
        debugPrint('Failed to add column status: $e');
      }
    }
  }

  // CRUD Operations for Recipes
  Future<int> insertRecipe(Recipe recipe) async {
    final db = await instance.database;
    try {
      return await db.insert('recipes', recipe.toMap());
    } catch (e) {
      debugPrint('Lỗi khi thêm công thức: $e');
      rethrow;
    }
  }

  Future<List<Recipe>> getAllRecipes() async {
    final db = await instance.database;
    final result = await db.query('recipes', orderBy: 'id DESC');
    return result.map((map) => Recipe.fromMap(map)).toList();
  }

  Future<int> updateRecipe(Recipe recipe) async {
    final db = await instance.database;
    return await db.update(
      'recipes',
      recipe.toMap(),
      where: 'id = ?',
      whereArgs: [recipe.id],
    );
  }

  Future<int> deleteRecipe(int id) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      return await txn.delete('recipes', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<Recipe>> searchRecipes(String keyword) async {
    final db = await instance.database;
    final result = await db.query(
      'recipes',
      where: 'title LIKE ? OR ingredients LIKE ?',
      whereArgs: ['%$keyword%', '%$keyword%'],
    );
    return result.map((e) => Recipe.fromMap(e)).toList();
  }

  Future<List<Recipe>> filterByDifficulty(String level) async {
    final db = await instance.database;
    final result = await db.query(
      'recipes',
      where: 'difficulty = ?',
      whereArgs: [level],
    );
    return result.map((e) => Recipe.fromMap(e)).toList();
  }

  Future<List<Recipe>> filterByNutrition(String tag) async {
    final db = await instance.database;
    final result = await db.query(
      'recipes',
      where: 'nutritionTag = ?',
      whereArgs: [tag],
    );
    return result.map((e) => Recipe.fromMap(e)).toList();
  }

  Future<Recipe?> getRecipeById(int id) async {
    final db = await instance.database;
    final maps = await db.query('recipes', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Recipe.fromMap(maps.first);
  }

  Future<List<Recipe>> getPendingRecipes() async {
    final db = await instance.database;
    final maps = await db.query(
      'recipes',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'id DESC',
    );
    return maps.map((m) => Recipe.fromMap(m)).toList();
  }

  Future<List<Recipe>> getApprovedRecipes() async {
    final db = await instance.database;
    final maps = await db.query(
      'recipes',
      where: 'status = ?',
      whereArgs: ['approved'],
      orderBy: 'id DESC',
    );
    return maps.map((m) => Recipe.fromMap(m)).toList();
  }

  Future<List<Recipe>> getUserRecipes(String userEmail) async {
    final db = await instance.database;
    final maps = await db.query(
      'recipes',
      where: 'createdBy = ?',
      whereArgs: [userEmail],
      orderBy: 'id DESC',
    );
    return maps.map((m) => Recipe.fromMap(m)).toList();
  }

  Future<List<Recipe>> getRecipesByStatus(String status) async {
    final db = await instance.database;
    final maps = await db.query(
      'recipes',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'id DESC',
    );
    return maps.map((m) => Recipe.fromMap(m)).toList();
  }

  Future<int> updateRecipeStatus(int id, String status) async {
    final db = await instance.database;
    return await db.update(
      'recipes',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, int>> getUserRecipeCounts(String userEmail) async {
    final recipes = await getUserRecipes(userEmail);
    return {
      'total': recipes.length,
      'pending': recipes.where((r) => r.status == 'pending').length,
      'approved': recipes.where((r) => r.status == 'approved').length,
    };
  }

  // User Operations
  Future<User> insertUser(User user) async {
    final db = await instance.database;
    final id = await db.insert('users', user.toMap());
    return user.copyWith(id: id);
  }

  Future<User?> getUser(String email, String password) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );
    if (maps.isEmpty) return null;
    return User.fromMap(maps.first);
  }

  // Database management
  Future<void> close() async {
    final db = await instance.database;
    await db.close();
    _database = null;
  }

  Future<void> backupDB() async {
    try {
      if (_database != null && _database!.isOpen) {
        await _database!.close();
      }

      final dbPath = await getDatabasesPath();
      final sourcePath = join(dbPath, 'recipes.db');
      final backupPath = join(dbPath, 'recipes_backup.db');

      File source = File(sourcePath);
      File dest = File(backupPath);

      await source.copy(dest.path);
      debugPrint('✅ Đã sao lưu database tại: ${dest.path}');

      _database = null;
      await database;
    } catch (e) {
      debugPrint('❌ Lỗi sao lưu database: $e');
    }
  }

  Future<void> restoreDB() async {
    try {
      final dbPath = await getDatabasesPath();
      final sourcePath = join(dbPath, 'recipes_backup.db');
      final destPath = join(dbPath, 'recipes.db');

      File source = File(sourcePath);
      File dest = File(destPath);

      await source.copy(dest.path);
      _database = null;
      debugPrint('✅ Đã phục hồi database từ: ${source.path}');
    } catch (e) {
      debugPrint('❌ Lỗi phục hồi database: $e');
    }
  }
}
