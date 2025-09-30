import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../data/models/invoice.dart';

/// Stores pending invoice submissions in a local SQLite table (sqflite).
/// Retries when connectivity becomes available.
class QueueService {
  static const _dbName = 'smart_pos_queue.db';
  static const _tableName = 'queue_jobs';

  Database? _db;
  final StreamController<List<QueueJob>> _jobsController = StreamController.broadcast();

  Stream<List<QueueJob>> get jobsStream => _jobsController.stream;

  Future<void> init() async {
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, _dbName),
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL,
            attempts INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'pending'
          )
        ''');
      },
    );
    await _emitJobs();
  }

  Future<void> resetFailedJobs() async {
    if (_db == null) return;
    final updated = await _db!.update(
      _tableName,
      {
        'status': 'pending',
        'attempts': 0,
      },
      where: 'status = ?',
      whereArgs: ['failed'],
    );
    if (updated > 0) {
      await _emitJobs();
    }
  }

  Future<void> enqueueInvoice(int receiptId) async {
    final payload = jsonEncode({'receipt_id': receiptId});
    await _db!.insert(_tableName, {
      'type': 'invoice_submit',
      'payload': payload,
      'created_at': DateTime.now().toIso8601String(),
      'attempts': 0,
      'status': 'pending',
    });
    await _emitJobs();
  }

  Future<void> retryFailedJob(int id) async {
    await _db!.update(
      _tableName,
      {'attempts': 0, 'status': 'pending'},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _emitJobs();
  }

  Future<void> processQueue(Future<void> Function(int receiptId) submitInvoice) async {
    final rows = await _db!.query(
      _tableName,
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'id ASC',
    );

    for (final row in rows) {
      final id = row['id'] as int;
      final attempts = row['attempts'] as int;
      final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      final receiptId = payload['receipt_id'] as int;

      try {
        await submitInvoice(receiptId);
        await _db!.delete(_tableName, where: 'id = ?', whereArgs: [id]);
      } catch (_) {
        final nextAttempts = attempts + 1;
        final status = nextAttempts >= 5 ? 'failed' : 'pending';
        await _db!.update(
          _tableName,
          {'attempts': nextAttempts, 'status': status},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }

    await _emitJobs();
  }

  Future<List<QueueJob>> loadJobs() async {
    final rows = await _db!.query(_tableName, orderBy: 'created_at DESC');
    return rows.map((row) {
      return QueueJob(
        id: row['id'] as int,
        type: row['type'] as String,
        payload: jsonDecode(row['payload'] as String) as Map<String, dynamic>,
        createdAt: DateTime.parse(row['created_at'] as String),
        attempts: row['attempts'] as int,
        status: row['status'] as String,
      );
    }).toList();
  }

  Future<void> _emitJobs() async {
    final jobs = await loadJobs();
    _jobsController.add(jobs);
  }

  Future<void> dispose() async {
    await _jobsController.close();
    await _db?.close();
  }
}
