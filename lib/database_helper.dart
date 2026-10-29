import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

typedef LogRecord = Map<String, dynamic>;
typedef LogList = List<dynamic>;

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
        await db.execute('''
          CREATE TABLE wanted (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            plate_number TEXT NOT NULL UNIQUE
          )
        ''');

        await db.execute('CREATE INDEX idx_wanted_plate ON wanted(plate_number)');

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

  Future<bool> checkIsWanted(String plate) async {
    final db = await instance.database;
    String cleanPlate = plate.replaceAll(' ', '');
    final maps = await db.rawQuery(
      "SELECT id FROM wanted WHERE REPLACE(plate_number, ' ', '') = ? LIMIT 1",
      [cleanPlate],
    );
    return maps.isNotEmpty;
  }

  Future<int> insertLog(LogRecord row) async {
    final db = await instance.database;
    return await db.insert('logs', row);
  }

  Future<LogList> getLogs() async {
    final db = await instance.database;
    return await db.query('logs', orderBy: 'id DESC');
  }

  Future<int> deleteLog(int id) async {
    final db = await instance.database;
    return await db.delete('logs', where: 'id = ?', whereArgs: [id]);
  }
}
