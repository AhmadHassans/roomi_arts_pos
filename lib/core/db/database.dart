import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// One local SQLite database file on the laptop. Fully offline.
///
/// Uses `sqflite_common_ffi` because plain `sqflite` has no desktop support.
/// Everything DB-related (init, schema, migrations) lives here so it is easy
/// to find and change later.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _fileName = 'roomi_arts.db';
  // v2 adds the `users` table (login/roles) and `sales.ref_invoice_no`
  // (links a return to the sale it refunds, so over-returns can be blocked).
  static const _version = 2;

  Database? _db;

  /// Full path to the single DB file. Exposed so Backup/Restore (M6) can copy it.
  String? dbPath;

  /// Call once at app start (before runApp).
  Future<void> init() async {
    // Wire up the FFI factory for desktop.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dir = await getApplicationSupportDirectory();
    dbPath = p.join(dir.path, _fileName);

    _db = await databaseFactory.openDatabase(
      dbPath!,
      options: OpenDatabaseOptions(
        version: _version,
        onConfigure: (db) async {
          // Enforce foreign keys.
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _createSchema,
        onUpgrade: _onUpgrade,
      ),
    );

    // The DB holds business data — keep it readable only by this user account.
    await _secureDbFile();
  }

  /// Restrict the DB file to the current user (owner read/write only) so it is
  /// not world-readable. POSIX only; on Windows the file already sits in the
  /// per-user AppData folder. Never fatal — a failure just logs and continues.
  Future<void> _secureDbFile() async {
    final path = dbPath;
    if (path == null || path == inMemoryDatabasePath) return;
    if (Platform.isWindows) return;
    try {
      await Process.run('chmod', ['600', path]);
    } catch (_) {
      // Best-effort hardening; the app still works if chmod is unavailable.
    }
  }

  /// Open a throwaway in-memory database for tests. No files, no path_provider.
  /// singleInstance:false so every call is a genuinely fresh, isolated db.
  Future<void> initInMemory() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    dbPath = inMemoryDatabasePath;
    await _db?.close();
    _db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: _version,
        singleInstance: false,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _createSchema,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Database get db {
    final d = _db;
    if (d == null) {
      throw StateError('AppDatabase.init() was not called.');
    }
    return d;
  }

  /// Close and reopen the DB. Used by Restore (M6) after replacing the file.
  Future<void> reopen() async {
    await _db?.close();
    _db = await databaseFactory.openDatabase(
      dbPath!,
      options: OpenDatabaseOptions(
        version: _version,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _createSchema,
        onUpgrade: _onUpgrade,
      ),
    );
    await _secureDbFile();
  }

  // ------------------------- Backup & Restore (M6) -------------------------

  /// Copy the whole DB file into [dirPath]. Returns the full path written.
  Future<String> backupTo(String dirPath, {required String fileName}) async {
    // Make sure everything is flushed to disk before copying.
    await _db?.close();
    _db = null;
    try {
      final dest = p.join(dirPath, fileName);
      await File(dbPath!).copy(dest);
      return dest;
    } finally {
      // Always reopen — even if the copy failed — so the app stays usable.
      await reopen();
    }
  }

  /// Replace the current DB with the chosen backup file, then reopen it.
  ///
  /// Safe by construction: the chosen file is validated as a real, intact
  /// Roomi Arts database BEFORE the live data is touched, and the current data
  /// is kept as a rollback copy so a failed restore never destroys anything.
  Future<void> restoreFrom(String backupPath) async {
    // 1. Reject anything that isn't a genuine, intact backup — before we
    //    overwrite a single byte of the live database.
    await _validateBackup(backupPath);

    // 2. Close the live DB and stash a rollback copy of the current data.
    await _db?.close();
    _db = null;
    final live = File(dbPath!);
    final rollback = File('${dbPath!}.rollback');
    final hadLive = await live.exists();
    if (hadLive) await live.copy(rollback.path);

    try {
      await File(backupPath).copy(dbPath!);
      await reopen();
    } catch (e) {
      // Restore failed after we started writing — put the old data back.
      if (hadLive) await rollback.copy(dbPath!);
      await reopen();
      rethrow;
    } finally {
      if (await rollback.exists()) await rollback.delete();
    }
  }

  /// Open the chosen file read-only and confirm it is an intact SQLite database
  /// that contains our tables. Throws a clear error otherwise. Never mutates
  /// the live database.
  Future<void> _validateBackup(String backupPath) async {
    if (!await File(backupPath).exists()) {
      throw const FileSystemException('Backup file not found.');
    }
    Database? probe;
    try {
      probe = await databaseFactory.openDatabase(
        backupPath,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      final integ = await probe.rawQuery('PRAGMA integrity_check');
      final firstVal = integ.isEmpty ? null : integ.first.values.first;
      if (firstVal is! String || firstVal.toLowerCase() != 'ok') {
        throw const FormatException('This backup file is damaged.');
      }
      final tables = await probe.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name IN ('products','sales','sale_items')",
      );
      if (tables.length < 3) {
        throw const FormatException('This file is not a Roomi Arts backup.');
      }
    } finally {
      await probe?.close();
    }
  }

  Future<void> _createSchema(Database db, int version) async {
    // products: stock always in smallest unit (pieces).
    await db.execute('''
      CREATE TABLE products (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        name          TEXT    NOT NULL,
        category      TEXT    NOT NULL,
        cost_price    REAL    NOT NULL DEFAULT 0,
        selling_price REAL    NOT NULL DEFAULT 0,
        stock_qty     INTEGER NOT NULL DEFAULT 0,
        unit          TEXT    NOT NULL DEFAULT 'piece',
        barcode       TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_products_name ON products(name)');
    await db.execute('CREATE INDEX idx_products_barcode ON products(barcode)');

    // sales: one row per completed sale OR return.
    await db.execute('''
      CREATE TABLE sales (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_no      TEXT    NOT NULL UNIQUE,
        date            TEXT    NOT NULL,
        total_amount    REAL    NOT NULL DEFAULT 0,
        discount_amount REAL    NOT NULL DEFAULT 0,
        payment_type    TEXT    NOT NULL DEFAULT 'cash',
        type            TEXT    NOT NULL DEFAULT 'sale',
        ref_invoice_no  TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_sales_invoice ON sales(invoice_no)');
    await db.execute('CREATE INDEX idx_sales_ref ON sales(ref_invoice_no)');
    await db.execute('CREATE INDEX idx_sales_date ON sales(date)');

    // sale_items: price/cost frozen at moment of sale (discount-aware refunds).
    await db.execute('''
      CREATE TABLE sale_items (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id       INTEGER NOT NULL,
        product_id    INTEGER NOT NULL,
        qty           INTEGER NOT NULL,
        price_at_sale REAL    NOT NULL,
        cost_at_sale  REAL    NOT NULL,
        FOREIGN KEY (sale_id)    REFERENCES sales(id),
        FOREIGN KEY (product_id) REFERENCES products(id)
      )
    ''');
    await db.execute('CREATE INDEX idx_sale_items_sale ON sale_items(sale_id)');

    await _createUsersTable(db);
  }

  /// Staff accounts for login/roles. Usernames are unique, case-insensitive.
  Future<void> _createUsersTable(Database db) async {
    await db.execute('''
      CREATE TABLE users (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        username      TEXT    NOT NULL UNIQUE COLLATE NOCASE,
        role          TEXT    NOT NULL,
        password_hash TEXT    NOT NULL
      )
    ''');
  }

  /// Bring an older database up to the current schema without losing data.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add the login/roles table and the return->sale link column.
      await _createUsersTable(db);
      await db.execute('ALTER TABLE sales ADD COLUMN ref_invoice_no TEXT');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_sales_ref ON sales(ref_invoice_no)');
    }
  }
}
