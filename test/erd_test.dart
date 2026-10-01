import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bootcamp_teamproject_1/models/erd_entities.dart';

void main() {
  final records =
      (jsonDecode(File('tool/erd_seed.json').readAsStringSync()) as List)
          .map(
            (record) =>
                ErpEntity.fromJson(Map<String, dynamic>.from(record as Map)),
          )
          .toList();

  test(
    'Photo has six entities and seven relationships, matching seed fields',
    () {
      expect(ErdCollection.all.where((c) => !c.isRelationship).length, 6);
      expect(ErdCollection.all.where((c) => c.isRelationship).length, 7);
      expect(ErdCollection.all.map((c) => c.id).toSet(), {
        'account',
        'employee',
        'manufactor',
        'quotation',
        'distributor_inventory',
        'office_inventory',
        'connect',
        'change',
        'resister',
        'recieve',
        'order',
        'send',
        'registration',
      });
      expect(records.length, 13);
      expect(
        records.map((r) => r.collection).toSet(),
        ErdCollection.all.map((c) => c.id).toSet(),
      );
      for (final schema in ErdCollection.all) {
        final record = records.singleWhere((r) => r.collection == schema.id);
        expect(
          record.toFirestore().keys.toSet(),
          schema.fields.keys.toSet(),
          reason: schema.id,
        );
      }
    },
  );

  test('All relationship keys resolve to entities in the same fixtures', () {
    Set<dynamic> values(String collection, String key) => records
        .where((r) => r.collection == collection)
        .map((r) => r.fields[key])
        .toSet();
    for (final record in records) {
      final fields = record.fields;
      for (final reference in {
        'email': ['account', 'email'],
        'employeeId': ['employee', 'employeeId'],
        'manufacturerId': ['manufactor', 'manufacturerId'],
        'productId': ['office_inventory', 'productId'],
        'branchName': ['distributor_inventory', 'branchName'],
        'quotationSeq': ['quotation', 'seq'],
      }.entries) {
        if (fields.containsKey(reference.key)) {
          expect(
            values(reference.value[0], reference.value[1]),
            contains(fields[reference.key]),
            reason: '${record.collection}.${reference.key}',
          );
        }
      }
    }
  });

  test(
    'Timestamp and boolean types survive fixture conversion without extra fields',
    () {
      final sent = records
          .singleWhere((r) => r.collection == 'send')
          .toFirestore();
      expect(sent['sentAt'], isA<Timestamp>());
      expect(
        (sent['sentAt'] as Timestamp).toDate().toUtc(),
        DateTime.parse('2026-09-30T10:00:00Z'),
      );
      expect(sent['isReceived'], false);
      expect(sent.containsKey('updatedAt'), false);
      expect(ErpEntity.displayValue('password', 'secret'), '••••••••');
      expect(ErpEntity.displayValue('isReceived', false), '아니오');
    },
  );
}
