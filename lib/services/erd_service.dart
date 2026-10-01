import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/erd_entities.dart';

class ErdService {
  ErdService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<ErpEntity>> watchCollection(ErdCollection collection) =>
      _firestore
          .collection(collection.id)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs
                    .map((doc) => ErpEntity.fromFirestore(collection.id, doc))
                    .toList()
                  ..sort((a, b) => a.id.compareTo(b.id)),
          );
}
