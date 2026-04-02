import '../../domain/models/customer_model.dart';
import '../db/app_database.dart';

class CustomerRepository {
  Future<List<CustomerModel>> getAll() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('customers', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map((e) => CustomerModel.fromMap(e)).toList();
  }

  Future<void> add(String name) async {
    final db = await AppDatabase.instance.database;
    await db.insert('customers', {'name': name.trim()});
  }

  Future<void> update(int id, String name) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'customers',
      {'name': name.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(int id) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

final customerRepository = CustomerRepository();