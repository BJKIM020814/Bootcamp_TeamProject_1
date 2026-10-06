import 'api_client.dart';
import 'fitpick_api_service.dart';

/// 회원 프로필은 FastAPI를 통해 Firebase 원본과 MySQL customer에 함께 반영한다.
/// Flutter가 Firestore account 문서 또는 비밀번호 필드에 직접 접근하지 않는다.
class AccountService {
  static Future<void> updateBasic(
    String _, {
    required String name,
    required String phone,
    required int shoeSize,
  }) async {
    try {
      await FitpickApiService.instance.updateAccountProfile(
        name: name,
        phoneNumber: phone,
        shoeSize: shoeSize,
      );
    } on FitpickApiException catch (error) {
      throw ApiException(error.message, error.statusCode);
    } catch (_) {
      throw ApiException('회원정보 저장 서버에 연결할 수 없습니다.');
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
