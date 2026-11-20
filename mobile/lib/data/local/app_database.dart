import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/warranty_model.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('varanti_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE local_warranties (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        item_name TEXT NOT NULL,
        merchant_name TEXT,
        category TEXT,
        purchase_date TEXT NOT NULL,
        warranty_duration_months INTEGER NOT NULL DEFAULT 12,
        warranty_expiration_date TEXT NOT NULL,
        serial_number TEXT,
        price_paid REAL,
        currency TEXT DEFAULT 'USD',
        receipt_image_url TEXT NOT NULL,
        receipt_image_path TEXT,
        serial_image_url TEXT,
        serial_image_path TEXT,
        notes TEXT,
        created_at TEXT,
        updated_at TEXT,
        is_local_only INTEGER DEFAULT 1
      )
    ''');

    await db.execute('CREATE INDEX idx_warranties_exp ON local_warranties(warranty_expiration_date);');
  }

  Future<List<WarrantyModel>> getWarranties({String? query, String? category}) async {
    final db = await instance.database;
    String whereClause = '';
    final List<dynamic> whereArgs = [];

    if (category != null && category.isNotEmpty) {
      whereClause += 'category = ?';
      whereArgs.add(category);
    }

    if (query != null && query.trim().isNotEmpty) {
      final search = '%${query.trim().toLowerCase()}%';
      final searchCondition =
          '(LOWER(item_name) LIKE ? OR LOWER(merchant_name) LIKE ? OR LOWER(serial_number) LIKE ?)';
      if (whereClause.isNotEmpty) {
        whereClause += ' AND $searchCondition';
      } else {
        whereClause = searchCondition;
      }
      whereArgs.addAll([search, search, search]);
    }

    final result = await db.query(
      'local_warranties',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'warranty_expiration_date ASC',
    );

    return result.map((json) => WarrantyModel.fromSqlite(json)).toList();
  }

  Future<WarrantyModel?> getWarrantyById(String id) async {
    final db = await instance.database;
    final result = await db.query(
      'local_warranties',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isNotEmpty) {
      return WarrantyModel.fromSqlite(result.first);
    }
    return null;
  }

  Future<void> insertWarranty(WarrantyModel warranty) async {
    final db = await instance.database;
    await db.insert(
      'local_warranties',
      warranty.toSqlite(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateWarranty(WarrantyModel warranty) async {
    final db = await instance.database;
    await db.update(
      'local_warranties',
      warranty.toSqlite(),
      where: 'id = ?',
      whereArgs: [warranty.id],
    );
  }

  Future<void> deleteWarranty(String id) async {
    final db = await instance.database;
    await db.delete(
      'local_warranties',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getCount() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM local_warranties');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> clearAll() async {
    final db = await instance.database;
    await db.delete('local_warranties');
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
