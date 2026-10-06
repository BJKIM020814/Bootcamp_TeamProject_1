# FITPICK iPhone 시뮬레이션 결과

실행일 2026-10-05 · Flutter 3.44.6 / Dart 3.12.2 · iPhone 17 Pro / iOS 26.5. 현재 Flutter 장치 목록에 Android 에뮬레이터가 없어 Android는 실행하지 않았다.

## 실행 환경

- FastAPI `python.fastapi.main:app`을 `127.0.0.1:18000`에 실행했다. MySQL은 이 Mac 로컬 인스턴스(`DB_HOST=127.0.0.1`)를 조회했고 서버 SQLite는 `/tmp/fitpick-codex-simulator.sqlite3`를 사용했다.
- 앱 빌드에는 `API_BASE_URL=http://127.0.0.1:18000`을 주입했다. Xcode Debug 빌드·시뮬레이터 설치·앱 시작이 성공했다.
- API `/health` 응답 정상, 통합 Swagger 필수 라우터 19개 누락 0, 상품 API가 DB 상품 11개 중 요청한 2개를 반환했다.
- iOS `GoogleService-Info.plist`는 저장소에 없다. `main.dart`는 Dart `FirebaseOptions`를 명시해 앱 화면은 시작했지만, 시뮬레이터 로그에서 plist 탐색 경고와 일부 Firebase SDK의 “app configured” 경고를 확인했다. 이 실행만으로 Firebase 클라이언트 기능의 연결을 성공으로 판정하지 않았다. 이 앱의 Discover 조회는 FastAPI/MySQL에서 정상 동작했다.
- MySQL/Firebase 실제 쓰기 요청, 가입·로그인 제출, 카드 결제는 하지 않았다.

## 실제 화면 흐름

| 단계 | 화면에서 확인한 결과 |
| --- | --- |
| 앱 시작 | 스플래시 뒤 홈 표시 |
| 하단 카테고리 | 상품 목록으로 이동, DB 11개, 대상·브랜드 필터 표시, DB에 용도 필드 없음 안내 |
| DB 상품 P1001 | 상품 상세·실제 색상 블랙·사이즈 270mm·구매 리뷰 표시 |
| 수령 지점 흐름 | 선택한 상품코드/색상/사이즈를 사이즈 확인 화면까지 전달, API 지점 5개 조회 및 강남 직영점 선택 |
| 장바구니/주문내역/마이 | 비로그인 상태에서 로그인 화면으로 이동 |
| 회원가입 진입 | 이름·이메일·비밀번호·전화·성별·주소·신발 사이즈(기본 270mm)·약관 입력 UI 표시 |

## 시뮬레이션 중 확인한 미완료 항목

1. **홈 추천 영역은 실제 상품 DB와 연결되지 않았다.** 정적 6개 상품 카드와 가격 문구가 있고 화면에 “27개의 실제 모델”이라고 표시된다. 두 수치는 현재 추천 데이터/API 응답을 나타내지 않는다. 홈의 용도 칩도 정적 6개 샘플만 필터링한다.
2. **추천 배너는 상세 대신 목록으로 이동한다.** 함수명은 상세 이동처럼 보이나 실제 구현은 `_openProductList()`를 부른다.
3. **옵션 누락 상품은 매장 단계로 못 간다.** 530 샘플 코드를 열면 DB에 해당 코드의 색상/사이즈가 없어 진행 버튼이 비활성화된다. 정상 옵션 상품 P1001은 다음 단계로 이동했다.
4. **선택한 픽업 지점이 다음 화면에 반영되지 않는다.** 지점 선택 페이지는 `PickupStore`를 pop으로 반환하지만 `SizeSelectionPage`는 반환값을 처리하지 않는다. 현재 지점 선택은 주문에 저장되지 않는다.
5. **장바구니·주문·마이는 로그인에 막혀 내부 화면을 시뮬레이션하지 못했다.** 이번 환경에서 테스트 계정 로그인을 제출하지 않았다. 현재 장바구니 화면은 메모리 데모 상품을 채우며 실제 주문/결제 DB 연결 증거가 아니다.
6. **가입은 폼 표시까지만 검사했다.** 기존 이용자 계정에 중복 가입하거나 실제 계정을 생성하지 않도록 제출하지 않았다.
7. **Firebase iOS SDK 초기화는 별도 확인이 필요하다.** 명시 옵션을 이용한 Flutter 시작과 화면 동작은 성공했지만 native plist 경고가 남아 있다. Auth·Firestore의 클라이언트 SDK 요청은 실행하지 않았다.

## 코드 주석 보완

`lib/main.dart` 초기화/개발 시드 조건, `lib/user/authController.dart` 실제 인증 경계, `lib/discover/home_page.dart` 고정 샘플과 비실시간 카운트, `lib/discover/splash_page.dart` 화면 전환, `lib/order/`의 데모 주문·결제·환불·교환·QR 한계, 마이페이지의 API 연결 여부, `size_selection_page.dart`의 미처리 지점 반환을 코드에 설명했다. 서버 시작점·인증 저장소·Discover 상품 옵션 조립 위치도 보완했고 잘못된 설명을 최신 구조에 맞췄다.

기존에 기능별 주석이 있던 파일은 반복 주석을 추가하지 않고 현재 동작과 다른 문구를 우선 정리했다. 시뮬레이션에서 발견한 기능 미완료는 주석으로 경계를 남겼으며 이 문서는 수정 요청이 없었던 화면 동작을 자동으로 바꾸지 않는다.

## 테스트 요약

- iOS simulator debug build/install/run: 성공.
- `python3 -m pytest python/fastapi/tests -q`: 51 passed.
- `flutter test`: 11 passed, 2 skipped(실 API 연결 테스트는 의도적으로 `RUN_LIVE_API_TESTS` 미설정).
- `flutter analyze`: 오류/경고 없음. 종료코드 1은 기존 Dart 파일명 스타일 안내 12건(`cartPage.dart`, `authController.dart` 등) 때문이다.
- `python3 -m compileall -q python/fastapi python/db.py`: 성공.
