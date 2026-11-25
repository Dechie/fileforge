import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:fileforge/core/constants/app_constants.dart';

/// Manages the SQLite database lifecycle.
class DatabaseHelper {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(documentsDir.path, AppConstants.dbName);

    return openDatabase(
      dbPath,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    // Processing jobs table
    await db.execute('''
      CREATE TABLE processing_jobs (
        id TEXT PRIMARY KEY,
        studio TEXT NOT NULL,
        operation TEXT NOT NULL,
        status TEXT NOT NULL,
        engine_id TEXT,
        engine_version TEXT,
        progress REAL DEFAULT 0.0,
        parameters TEXT,
        input_refs TEXT,
        output_refs TEXT,
        error_message TEXT,
        created_at TEXT NOT NULL,
        started_at TEXT,
        completed_at TEXT
      )
    ''');

    // Storage tracking table
    await db.execute('''
      CREATE TABLE tracked_files (
        path TEXT PRIMARY KEY,
        file_type TEXT NOT NULL,
        job_id TEXT,
        size_bytes INTEGER,
        created_at TEXT NOT NULL
      )
    ''');

    // Processing checkpoints table
    await db.execute('''
      CREATE TABLE checkpoints (
        job_id TEXT PRIMARY KEY,
        input_identity TEXT NOT NULL,
        input_hash TEXT,
        engine_id TEXT NOT NULL,
        engine_version TEXT NOT NULL,
        parameters TEXT,
        completed_units INTEGER DEFAULT 0,
        total_units INTEGER DEFAULT 0,
        intermediate_paths TEXT,
        recovery_capability TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (job_id) REFERENCES processing_jobs(id)
      )
    ''');

    // Settings table
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Indices
    await db.execute('CREATE INDEX idx_jobs_status ON processing_jobs(status)');
    await db.execute('CREATE INDEX idx_jobs_studio ON processing_jobs(studio)');
    await db.execute(
      'CREATE INDEX idx_tracked_files_job ON tracked_files(job_id)',
    );
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Future migrations go here.
  }

  static Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
