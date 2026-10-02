import 'package:cloud_firestore/cloud_firestore.dart';

import 'api_client.dart';
import 'fitpick_api_service.dart';

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

  /// 해시 계정과 호환되도록 서버 세션 소유자의 비밀번호를 변경한다.
  static Future<void> changePassword(
    String email, {
    required String current,
    required String next,
  }) async {
    try {
      await FitpickApiService.instance.changePassword(
        current: current,
        next: next,
      );
    } on FitpickApiException catch (error) {
      throw ApiException(error.message, error.statusCode);
    } catch (_) {
      throw ApiException('비밀번호 변경 서버에 연결할 수 없습니다.');
    }
  }
}
