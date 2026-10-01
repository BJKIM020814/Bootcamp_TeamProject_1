import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import '../models/erd_entities.dart';

class ErdSeedService {
  ErdSeedService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// 명시적으로 SEED_ERD=true일 때만 실행. 기존 문서는 덮어쓰지 않는다.
  Future<void> seedTestData() async {
    final source = await rootBundle.loadString('tool/erd_seed.json');
    final records = (jsonDecode(source) as List)
        .map(
          (value) =>
              ErpEntity.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList();
    final refs = records
        .map(
          (record) => _firestore.collection(record.collection).doc(record.id),
        )
        .toList();

    await _firestore.runTransaction((transaction) async {
      final snapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final ref in refs) {
        snapshots.add(await transaction.get(ref));
      }
      for (var i = 0; i < records.length; i++) {
        if (!snapshots[i].exists) {
          transaction.set(refs[i], records[i].toFirestore());
        }
      }
    });
  }
}
