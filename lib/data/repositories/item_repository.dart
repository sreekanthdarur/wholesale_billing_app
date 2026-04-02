import '../../domain/models/item_model.dart';
import '../db/app_database.dart';

class ItemRepository {
  Future<List<ItemModel>> getAll() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('items', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map((e) => ItemModel.fromMap(e)).toList();
  }

  Future<ItemModel?> findByName(String name) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'items',
      where: 'LOWER(name) = ?',
      whereArgs: [name.trim().toLowerCase()],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return ItemModel.fromMap(rows.first);
  }

  Future<void> add(ItemModel item) async {
    final db = await AppDatabase.instance.database;
    await db.insert('items', item.toMap());
  }

  Future<void> update(ItemModel item) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> addIfMissing(ItemModel item) async {
    final existing = await findByName(item.name);
    if (existing != null) return;
    await add(item);
  }
}

final itemRepository = ItemRepository();