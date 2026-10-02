import 'package:cloud_firestore/cloud_firestore.dart';

import 'api_client.dart';

/// Firebase `account` 컬렉션(이름/전화번호/비밀번호) 접근.
/// 회원정보는 Firebase 가, 쇼핑 데이터는 MySQL(FastAPI)이 맡는 기존 구조를 따른다.
/// 로그인 화면(loginpage.dart)과 같이 email 로 문서를 찾는다.
class AccountService {
  static Future<DocumentSnapshot<Map<String, dynamic>>> _find(
    String email,
  ) async {
    try {
      final result = await FirebaseFirestore.instance
          .collection('account')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (result.docs.isEmpty) throw ApiException('등록되지 않은 계정입니다.');
      return result.docs.first;
    } on FirebaseException {
      throw ApiException('계정 정보를 불러올 수 없습니다. 다시 시도해 주세요.');
    }
  }

  static Future<({String name, String phone})> getBasic(String email) async {
    final data = (await _find(email)).data() ?? {};
    return (
      name: '${data['name'] ?? ''}',
      phone: '${data['phoneNumber'] ?? ''}',
    );
  }

  static Future<void> updateBasic(
    String email, {
    required String name,
    required String phone,
  }) async {
    final doc = await _find(email);
    try {
      await doc.reference.update({'name': name, 'phoneNumber': phone});
    } on FirebaseException {
      throw ApiException('저장하지 못했습니다. 다시 시도해 주세요.');
    }
  }

  /// 현재 비밀번호가 맞을 때만 새 비밀번호로 바꾼다.
  /// 기존 로그인(loginpage.dart)이 평문 password 필드를 비교하는 구조라 같은 방식으로 저장한다.
  static Future<void> changePassword(
    String email, {
    required String current,
    required String next,
  }) async {
    final doc = await _find(email);
    if ((doc.data() ?? {})['password'] != current) {
      throw ApiException('현재 비밀번호가 일치하지 않습니다.');
    }
    try {
      await doc.reference.update({'password': next});
    } on FirebaseException {
      throw ApiException('비밀번호를 변경하지 못했습니다. 다시 시도해 주세요.');
    }
  }
}
