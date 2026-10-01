import 'package:cloud_firestore/cloud_firestore.dart';

/// 사진의 엔티티 6개 + 관계 7개. 기존 Firebase 컬렉션명을 그대로 유지한다.
/// manufactor / resister / recieve의 기존 철자도 연결 호환성을 위해 유지한다.
class ErdCollection {
  const ErdCollection(this.id, this.label, this.isRelationship, this.fields);

  final String id;
  final String label;
  final bool isRelationship;
  final Map<String, String> fields;

  static const all = <ErdCollection>[
    ErdCollection('account', '회원', false, {
      'email': '이메일',
      'password': 'password',
      'phoneNumber': '전화번호',
      'name': '이름',
      'gender': '성별',
      'address': '주소',
      'signupPath': '가입경로',
    }),
    ErdCollection('employee', '직원(본사 서버)', false, {
      'employeeId': '직원 ID',
      'password': '직원 password',
      'position': '직급',
      'department': '부서',
      'businessNumber': '사업자번호',
    }),
    ErdCollection('manufactor', '제조사', false, {
      'manufacturerId': '제조사 ID',
      'manufacturerName': '제조사명',
      'address': '주소',
    }),
    ErdCollection('quotation', '견적서', false, {
      'supplyPrice': '공급가',
      'productName': '상품명',
      'unitPrice': '단가',
      'quantity': '수량',
      'seq': 'seq',
      'quotedAt': '날짜',
      'managerName': '담당자명',
    }),
    ErdCollection('distributor_inventory', '대리점재고', false, {
      'branchName': '지점명',
      'quantity': '대리점재고',
      'productId': '제품 ID',
    }),
    ErdCollection('office_inventory', '본사재고', false, {
      'productId': '제품 ID',
      'minimumQuantity': '최소수량',
    }),
    ErdCollection('connect', '접속하다', true, {
      'email': '회원 이메일',
      'employeeId': '직원 ID',
      'connectedAt': '접속일자',
      'accessLocation': '접속위치',
      'ipAddress': 'IP 주소',
    }),
    ErdCollection('change', '변경하다', true, {
      'email': '회원 이메일',
      'employeeId': '직원 ID',
      'changedAt': '변경일자',
    }),
    ErdCollection('resister', '등록하다', true, {
      'email': '회원 이메일',
      'employeeId': '직원 ID',
      'registeredAt': '등록일자',
    }),
    ErdCollection('recieve', '수주하다', true, {
      'employeeId': '직원 ID',
      'manufacturerId': '제조사 ID',
      'receivedAt': '수주일',
      'quantity': '수주량',
      'productId': '제품 ID',
    }),
    ErdCollection('order', '발주하다', true, {
      'employeeId': '직원 ID',
      'manufacturerId': '제조사 ID',
      'quotationSeq': '견적서 seq',
      'productId': '제품 ID',
      'orderedAt': '발주일',
      'quantity': '발주량',
    }),
    ErdCollection('send', '재고를 발송하다', true, {
      'employeeId': '직원 ID',
      'branchName': '지점명',
      'quantity': '발송수량',
      'sentAt': '발송일',
      'isReceived': '수령여부',
    }),
    ErdCollection('registration', '재고를 등록하다', true, {
      'employeeId': '직원 ID',
      'productId': '제품 ID',
      'quantity': '재고 현황',
      'brandName': '브랜드명',
      'registeredAt': '재고등록일',
    }),
  ];
}

/// 필드명은 Firebase 원본 그대로 보존하고, 화면에서는 ErdCollection의 한글명을 쓴다.
class ErpEntity {
  const ErpEntity(this.collection, this.id, this.fields);

  final String collection;
  final String id;
  final Map<String, dynamic> fields;

  factory ErpEntity.fromFirestore(
    String collection,
    DocumentSnapshot<Map<String, dynamic>> document,
  ) => ErpEntity(collection, document.id, document.data() ?? {});

  factory ErpEntity.fromJson(Map<String, dynamic> record) => ErpEntity(
    record['collection'] as String,
    record['id'] as String,
    Map<String, dynamic>.from(record['fields'] as Map),
  );

  Map<String, dynamic> toFirestore() => fields.map(
    (key, value) => MapEntry(
      key,
      key.endsWith('At') && value is String
          ? Timestamp.fromDate(DateTime.parse(value))
          : value,
    ),
  );

  static String displayValue(String key, dynamic value) {
    if (key.toLowerCase().contains('password')) return '••••••••';
    if (value == null) return '—';
    if (value is Timestamp) return value.toDate().toLocal().toString();
    if (value is bool) return value ? '예' : '아니오';
    return value.toString();
  }
}
