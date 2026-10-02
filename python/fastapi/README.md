# FITPICK 페이지 백엔드

기존 Flutter 화면 및 세 장의 ERD를 연결하기 위한 FastAPI 서버다.
백엔드 위치는 현재 프로젝트의 `python/fastapi` 폴더다. 실제 서버 프레임워크 이름은 FastAPI다.

## 페이지별 파일 및 연결 데이터

| 페이지 | 파일 | 저장소 / 연결 |
|---|---|---|
| 리뷰관리 | `review_management.py` | MySQL `review` + `product`, 로그인 회원의 리뷰만 조회/수정/삭제 |
| 리뷰작성 | `review_write.py` | MySQL `purchase`로 구매 확인 → `review` 등록 |
| 알림 | `notifications.py` | **추가한 서버 SQLite** `notifications` |
| 앱설정 | `app_settings.py` | **추가한 서버 SQLite** `app_settings` |
| 고객센터 | `customer_support.py` | MySQL `contact`, FAQ는 기존 화면의 안내 문구 |
| 로그인 | `login.py` | Firebase `account` → 서버 SQLite `api_sessions` |
| 회원가입 | `signup.py` | Firebase `account` 생성 → MySQL `customer` 연결 |
| 본사 관리자 | `headquarters/` | 주문·재고·결재·매출·대리점·계약 (기능별 API 및 제약은 [안내](headquarters/README.md)) |

공통 연결 키는 **이메일**이다: `account.email = customer.customer_id =
review.customer_customer_id = contact.customer_customer_id`.
상품 키는 기존 Python 코드의 `product.p_code = review.product_p_code = purchase.p_code`를 사용한다.
Firebase 재고의 `productId`도 기존 코드상 동일한 상품 코드다.

스크린샷에서 MySQL `customer_id`/`product_id`가 INT로 보이는 부분은 기존 Python 코드와 다르다.
이 서버는 현재 코드의 문자열 이메일/`p_code`를 우선한다. 실제 MySQL이 스크린샷의 INT 모델이면
회원 매핑 테이블과 상품 키 매핑이 추가로 필요하므로 아래 스키마 검사를 먼저 실행해야 한다.
Firebase의 직원 password, 재고/등록/수주/발주 데이터는 이 회원용 API에 노출하지 않는다.

세 번째 SQLite ERD는 장바구니/쿠폰/관심상품/최근 본 상품용이며, 요청한 알림/설정 필드는 없다.
이번에 만든 SQLite는 **FastAPI 서버 파일**이고 앱 기기의 sqflite DB와 공유되지 않는다.
원본 ERD 테이블을 알림으로 재해석하거나 수정하지 않았다.

## 실행

프로젝트 루트에서 Python 3.9 이상으로 실행한다. 신규 환경은 Python 3.11 이상 권장.

```sh
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
# 기존 .env가 없을 때만 복사. 기존 DB 설정을 덮어쓰지 말 것.
cp python/fastapi/config.env.example .env
python -m python.fastapi.check_schema
uvicorn python.fastapi.main:app --reload --host 0.0.0.0 --port 8000
```

- Swagger 요청 테스트: http://127.0.0.1:8000/docs
- OpenAPI 계약: http://127.0.0.1:8000/openapi.json
- 프로세스 상태: http://127.0.0.1:8000/health (DB 연결 상태 검사는 아님)
- `.env`의 DB_*는 기존 `python/db.py`에서도 읽는다.
- Firebase는 기존 `shoe-20260930/(default)` STANDARD 인스턴스 사용.
- Python SDK 인증은 Google ADC 또는 `GOOGLE_APPLICATION_CREDENTIALS` 필요.
  Firebase CLI 로그인만으로 Python 서버가 인증되지는 않는다.
- 서비스 계정 JSON은 저장소 밖에 둔다.
- `SUPPORT_HEAD_OFFICE_ID`에 실제 `contact.head_office_id` FK 값을 설정해야 문의 등록 가능.
- MySQL 자동 마이그레이션은 하지 않는다. [스키마 확인 안내](sql/README.md) 참고.
- `API_SQLITE_PATH`는 기본 `python/fastapi/data/app.sqlite3`. 재시작/배포 시 이 파일을 보존해야 한다.
  여러 서버 인스턴스에서는 공유 DB로 교체해야 세션/설정/알림이 공유된다.

## 인증 흐름

회원가입/로그인/FAQ 외의 페이지 API는 `Authorization: Bearer <accessToken>` 헤더가 필요하다.
회원 이메일을 URL/본문에 보내서 타인의 데이터를 선택할 수 없고 서버가 토큰으로 결정한다.

```json
POST /api/signup
{
  "email": "user@example.com",
  "password": "a-long-password",
  "name": "홍길동",
  "phoneNumber": "010-1234-5678",
  "gender": "선택 안 함",
  "address": "서울",
  "signupPath": "이메일",
  "age": 25,
  "agreed": true
}
```

`gender`, `signupPath`, `age`는 선택. 약관 동의는 필수. signupPath는 이메일 가입만 지원한다.
구글/네이버 가입은 인증 공급자 연결이 없어 이 서버에서 처리하지 않는다.
회원 응답에는 password를 포함하지 않는다. 신규 password는 기존 필드명 안에 Argon2 해시로 저장한다.

```json
{
  "accessToken": "...",
  "tokenType": "bearer",
  "expiresAt": 1790000000,
  "account": {
    "email": "user@example.com", "name": "홍길동", "phoneNumber": "010-1234-5678",
    "gender": "선택 안 함", "address": "서울", "signupPath": "이메일"
  },
  "customerSynced": true,
  "nextAction": null
}
```

Firebase/MySQL 간 분산 트랜잭션은 없다. Firebase 가입 후 MySQL 장애가 발생하면 가입은 유지되고
`customerSynced:false`, `nextAction:"POST /api/signup/sync"`를 반환한다.
해당 토큰으로 sync를 재시도하면 기존 고객 데이터를 덮어쓰지 않고 연결할 수 있다.
앱 재시작 후에는 로그인해서 sync를 호출할 수도 있다. sync 재시도는 선택 age를 새로 입력하지 않는다.
이 때 MySQL age는 기존 값을 유지하거나 신규 연결 시 빈 값으로 시작한다.

```json
POST /api/login
{"email":"user@example.com","password":"a-long-password"}
```

로그인 응답은 accessToken/tokenType/expiresAt/account. 기본 세션 만료는 1시간이고 서버에는 토큰 해시만 저장한다.
`GET /api/login/me`는 회원정보, `POST /api/login/logout`은 해당 세션을 즉시 폐기(204)한다.
기존 평문 테스트 계정은 기본 로그인 차단. 필요한 개발 환경에서만
`ALLOW_LEGACY_PASSWORD_LOGIN=true`로 최초 로그인 시 password를 해시로 변환한다.
Flutter 로그인/회원가입 화면은 REST 어댑터로 연결했다. 가입 성공 후 로그인 화면으로 복귀하고 이메일을 자동 입력한다.
신규 account 문서 ID는 `api-<email SHA256>`이며, 기존 문서는 email 조회로 찾고 문서 ID를 보존한다.

현재 저장소의 Firestore rules는 테스트용 전체 접근 허용 상태다. 서버 세션은 Firebase Auth 토큰이 아니다.
실제 계정 사용 전에 Firestore `account`의 클라이언트 직접 접근을 차단하고 회원 조회를 API로 옮겨야 한다.
이번 작업은 원격 규칙/테이블/계정을 변경하거나 배포하지 않는다.

## API 계약

목록 응답 공통: `{"items": [...], "total": 0, "limit": 20, "offset": 0}`.
`limit` 1~100, `offset` 0 이상. 빈 목록은 성공(200), 페이지에서 빈 상태를 표시한다.

| 메서드 | URL (/api 기준) | 기능 |
|---|---|---|
| GET | /reviews | 내가 작성한 리뷰 |
| GET | /reviews/{id} | 내 리뷰 상세 |
| PUT | /reviews/{id} | 내 리뷰 수정 |
| DELETE | /reviews/{id} | 내 리뷰 삭제 (204) |
| GET | /reviewable-products | 구매했고 리뷰를 아직 작성하지 않은 상품 |
| POST | /reviews | 리뷰 작성 (201) |
| GET | /notifications | 내 알림 목록 및 unreadCount |
| PATCH | /notifications/{id}/read | 내 알림 읽음 처리 |
| PATCH | /notifications/read-all | 내 알림 전체 읽음 처리, updatedCount |
| GET | /settings | 내 설정 및 appVersion |
| PATCH | /settings | 선택한 설정 변경 |
| GET | /support/faqs | 기존 FAQ 목록 (인증 불필요) |
| GET | /support/contacts | 내 문의 목록 |
| GET | /support/contacts/{id} | 내 문의 및 답변 상세 |
| POST | /support/contacts | 문의 접수 (201) |
| POST | /login/password | 현재 비밀번호 검증 후 새 비밀번호 해시 저장 (204) |
| POST | /signup/sync | 로그인 회원의 MySQL 고객 연결 재시도 |

리뷰 등록:
```json
{"productCode":"실제 구매 상품 p_code","rating":5,"content":"실제로 착용해 보니 편안하고 좋습니다.","fit":"정사이즈"}
```
수정은 위에서 productCode만 제외한다. rating 1~5 정수, content 10~2000자,
fit은 작아요/정사이즈/커요. 상품당 회원별 리뷰 1개. 미구매 403, 중복 409.
현재는 텍스트 리뷰를 구현했고 `review.image`에는 빈 BLOB을 넣는다. 사진 업로드는 별도 미구현.
리뷰 응답: id/productCode/productName/brand/content/rating/fit/createdAt/likeCount.
작성가능 상품 응답: productCode/productName/brand.
기존 purchase에 배송완료 상태 필드가 없어 구매 여부까지만 확인한다.

설정 변경:
```json
{"orderNotification":true,"marketingNotification":false}
```
기본값은 주문 true / 마케팅 false. PATCH에는 변경한 항목만 보내도 된다.
null은 허용하지 않는다. appVersion은 서버 설정 값이다.

문의 등록:
```json
{"content":"주문한 상품의 픽업 날짜를 확인하고 싶습니다."}
```
이미지 contact.context VARCHAR(50) 기준으로 **1~50자**. 장문 문의는 DB와 입력 검증을 함께 확장해야 한다.
문의 응답: id/content/createdAt/response/respondedAt/process. process 0은 접수,
응답 내용/일자/처리 상태는 본사 시스템이 MySQL에 기록한 값을 그대로 조회한다.
회원 API에는 답변 생성 권한을 제공하지 않는다.

알림 응답은 공통 목록 외에 unreadCount가 있으며 항목은 id/category/title/body/createdAt/readAt.
readAt이 null이면 읽지 않은 알림. 문의 접수 시 support 알림을 생성한다.
주문/마케팅 이벤트는 다른 백엔드에서 `LocalStore.add_notification(email,category,title,body)`를 호출해야 한다.
order/marketing 설정이 꺼져 있으면 해당 알림 생성을 건너뛴다. 푸시(FCM), 주문 이벤트 연결,
본사 답변 이벤트 연결은 구현하지 않았다. 알림은 앱 내 목록 저장이다.

시간: MySQL의 createdAt/respondedAt은 UTC 기준 timezone 없는 ISO 문자열,
SQLite의 알림 시간은 UTC offset이 있는 ISO 문자열. expiresAt은 Unix 초.
프론트는 MySQL 응답 시간에 UTC를 지정한 후 현지 시간으로 표시한다.

오류 응답: `{"detail":"..."}`. 401 로그인/세션 만료, 403 권한/미구매,
404 존재하지 않거나 타인의 항목, 409 중복/회원 연결 필요,
422 입력검증(detail 배열), 503 DB 설정/연결 오류. 성공 204는 응답 본문 없음.

## Flutter 프론트 연결

`lib/services/fitpick_api_service.dart`가 모든 API의 호출 함수를 제공한다.
로그인/회원가입 화면은 API에 연결했다. 회원가입은 자동 로그인 없이 성공 후 로그인 화면으로 이동한다. 나머지 화면은 다음과 같이 연결한다.

```dart
final api = FitpickApiService.instance;
final result = await api.login(email, password);
AuthController.to.login(); // 기존 UI 로그인 상태 갱신
final rows = (await api.reviews())['items'];
```

| 기존 화면 | 사용할 어댑터 메서드 |
|---|---|
| loginpage.dart | login → 기존 AuthController.login / 화면 이동 |
| signuppage.dart | signup(startSession: false) → 성공 안내 → 로그인 화면 이동 |
| reviewmanagementpage.dart | reviews, review, updateReview, deleteReview |
| reviewwritepage.dart | reviewableProducts에서 productCode 선택 → writeReview |
| notificationpage.dart | notifications, readNotification, readAllNotifications |
| settingspage.dart | settings 로드 → updateSettings 성공 후 switch 반영 |
| customersupportpage.dart | faqs, contacts, contact, writeContact |

현재 리뷰작성 화면에는 상품 선택/핏 입력이 없다. 작성가능 상품 선택 UI를 추가하거나
주문 화면에서 productCode를 전달해야 한다. 기존 별점과 content는 그대로 요청에 사용한다.
현재 고객센터 화면에는 문의 작성/목록 UI가 없으므로 위 메서드로 추가한다.
화면에서 로딩/빈 상태/오류를 처리하고 async 후 mounted 확인을 한다.
401이면 기존 AuthController.logout을 호출하고 로그인 화면으로 이동한다.
로그아웃 시 api.logout과 AuthController.logout을 함께 호출한다.
REST 어댑터 토큰은 메모리에만 보관되어 앱 재시작 후 재로그인이 필요하다.

```sh
# iOS 시뮬레이터/macOS
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
# Android 기본 에뮬레이터
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
# 실제 기기는 컴퓨터의 LAN IP 사용
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000
```

API_BASE_URL 끝에 /api 또는 /를 붙이지 않는다. 웹은 실행 origin을 API_CORS_ORIGINS에 추가한다.
플랫폼 HTTP 개발 허용 설정이 별도로 필요할 수 있으며 실제 배포에서는 HTTPS를 사용한다.

## 검증

```sh
pip install -r python/fastapi/requirements-dev.txt
python -m pytest python/fastapi/tests -q
flutter test test/fitpick_api_service_test.dart
python -m python.fastapi.check_schema
```

테스트는 실제 SQLite + 대체 Firebase/MySQL 저장소로 API 계약, 토큰 만료/폐기,
회원별 데이터 격리, 검증 오류, 회원가입 부분 실패/재시도 및 MySQL 쿼리 구매/중복/소유자 조건을 검사한다.
외부 Firebase/MySQL에 테스트 계정을 만들지 않는다. 실제 연결 검증은 별도로 필요하다.
구현 참고: [FastAPI 인증 문서](https://fastapi.tiangolo.com/tutorial/security/oauth2-jwt/),
[Firestore Python 조회](https://docs.cloud.google.com/firestore/docs/samples/firestore-data-query-async).

최신 main의 `/api/v1/discover`, `/api/v1/mypage` 라우터와 `/test` 안내 페이지도 공통 서버에 함께 등록한다. 비밀번호 변경 요청은 `{"current":"현재 비밀번호","next":"새 비밀번호"}` 형식이며 기존 Flutter 변경 화면도 이 API에 연결했다.
