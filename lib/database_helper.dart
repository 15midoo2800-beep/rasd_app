import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tracking_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // جدول السيارات المطلوبة
        await db.execute('''
          CREATE TABLE wanted (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            plate_number TEXT NOT NULL UNIQUE
          )
        ''');

        // فهرس فوري للبحث في أجزاء من الثانية
        await db.execute('CREATE INDEX idx_wanted_plate ON wanted(plate_number)');

        // جدول سجلات الرصد الميداني
        await db.execute('''
          CREATE TABLE logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            plate TEXT NOT NULL,
            status INTEGER NOT NULL,
            type TEXT,
            street TEXT,
            district TEXT,
            note TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        ''');
      },
    );
  }

  // فحص اللوحة هل هي مطلوبة أم لا
  Future<bool> checkIsWanted(String plate) async {
    final db = await instance.database;
    String cleanPlate = plate.replaceAll(' ', '');
    final maps = await db.rawQuery(
      "SELECT id FROM wanted WHERE REPLACE(plate_number, ' ', '') = ? LIMIT 1",
      [cleanPlate],
    );
    return maps.isNotEmpty;
  }

  // إدراج سجل رصد جديد
  Future<int> insertLog(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('logs', row);
  }

  // جلب كافة سجلات الرصد
  Future<List>> getLogs() async {
    final db = await instance.database;
    return await db.query('logs', orderBy: 'id DESC');
  }

  // حذف سجل
  Future<int> deleteLog(int id) async {
    final db = await instance.database;
    return await db.delete('logs', where: 'id = ?', whereArgs: [id]);
  }
}
