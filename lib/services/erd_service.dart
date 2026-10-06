import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/erd_entities.dart';

/// Firestore ERD 컬렉션을 앱의 공통 엔티티 모델로 제공한다.
class ErdService {
  /// 테스트에서는 별도 Firestore 인스턴스를 주입할 수 있다.
  ErdService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// 컬렉션 문서 변경을 구독하고 문서 ID 오름차순으로 정렬해 전달한다.
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
