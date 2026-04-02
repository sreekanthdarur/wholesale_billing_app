import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _database;

  Future<Database> get database async {
    _database ??= await _open();
    return _database!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'wholesale_billing_app.db');

    return openDatabase(
      path,
      version: 3,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createTables(db);
        await _seedDefaults(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _createTables(db);
        await _safeAddInvoiceTypeColumn(db);
        await _seedDefaults(db);
      },
      onOpen: (db) async {
        await _createTables(db);
        await _safeAddInvoiceTypeColumn(db);
        await _seedDefaults(db);
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        price REAL NOT NULL,
        unit TEXT NOT NULL,
        aliases_csv TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_no TEXT NOT NULL UNIQUE,
        invoice_date TEXT NOT NULL,
        invoice_type TEXT,
        customer_name TEXT NOT NULL,
        source_mode TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        raw_input_text TEXT NOT NULL DEFAULT '',
        total REAL NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoice_lines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        item_name TEXT NOT NULL,
        qty REAL NOT NULL,
        unit TEXT NOT NULL,
        rate REAL NOT NULL,
        amount REAL NOT NULL,
        is_custom_rate INTEGER NOT NULL DEFAULT 0,
        needs_review INTEGER NOT NULL DEFAULT 0,
        source_text TEXT NOT NULL DEFAULT '',
        FOREIGN KEY(invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _safeAddInvoiceTypeColumn(Database db) async {
    final columns = await db.rawQuery("PRAGMA table_info(invoices)");
    final hasInvoiceType = columns.any((c) => c['name'] == 'invoice_type');
    if (!hasInvoiceType) {
      await db.execute('ALTER TABLE invoices ADD COLUMN invoice_type TEXT');
    }
  }

  Future<void> _seedDefaults(Database db) async {
    for (final customer in AppConstants.defaultCustomers) {
      await db.insert(
        'customers',
        {'name': customer},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    for (final entry in AppConstants.itemDefaults.entries) {
      final name = entry.key;
      final defaults = entry.value;
      final aliases = AppConstants.itemAliases[name]?.join(', ') ?? '';

      await db.insert(
        'items',
        {
          'name': name,
          'price': defaults['rate'],
          'unit': defaults['unit'],
          'aliases_csv': aliases,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }
}