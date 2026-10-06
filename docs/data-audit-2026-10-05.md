# FITPICK 코드·저장소 데이터 계약 점검

점검일: 2026-10-05. 대상 저장소: `Bootcamp_TeamProject_1`.

## 결론과 범위

**전체 기능 연동 완료 상태가 아니다.** MySQL 23개 테이블, Firestore 13개 컬렉션, Firebase Authentication을 읽기 전용으로 조사했다. 권한 누락, 계정 전환 잔상, 잘못된 API 경로, 상품 옵션 코드 연결, 스키마 불일치의 무분별한 실행은 코드에서 보완했다. 기존 데이터의 매핑·누락 문제는 별도 결정이 필요하다.

- 이번 점검에서는 MySQL/Firestore/Auth 데이터를 생성·수정·삭제하지 않았다. 실제 회원가입·로그인·주문 요청도 실행하지 않았다.
- MySQL은 `START TRANSACTION READ ONLY`로 조사했다. 수정 전후 23개 테이블의 전체 행 지문이 모두 동일하다. Firestore 문서 수·필드 존재/NULL 통계도 동일하다(내용 전체 지문 검사는 아님).
- 개인정보·비밀번호·키 값은 보고서에 기록하지 않았다. 상세 컬럼, 인덱스, 실제 FK와 집계는 [스키마 JSON](data-audit-2026-10-05.json)에 있다.
- `.env`의 이전 LAN 주소 `192.168.20.68`로는 연결되지 않았다. 같은 Mac의 MySQL에 **프로세스 환경변수 `DB_HOST=127.0.0.1`만 덮어써서** 실제 조회했다. `.env` 파일은 변경하지 않았다. 따라서 기존 `.env` 그대로 실행되는 팀원 환경의 성공을 의미하지 않는다.
- Firebase 프로젝트는 `shoe-20260930`, Firestore DB는 `(default)`이다.
- 이미 존재하던 미커밋 수정은 보존했다. Git 커밋·push·배포를 수행하지 않았다. 이전 작업의 Firebase 변경 여부와 이번 읽기 전용 검사는 구분해야 한다.

## 파일 구조와 책임

| 영역 | 파일/디렉터리 | 책임 및 주의점 |
| --- | --- | --- |
| Flutter 진입/설정 | `lib/main.dart`, `lib/firebase_options.dart`, `lib/services/api_config.dart` | Firebase 초기화 및 공통 API 주소 |
| Discover | `lib/discover/` | 상품 검색·목록·상세·옵션·픽업 매장 선택 |
| 고객 계정 | `lib/user/loginpage.dart`, `signuppage.dart`, `authController.dart` | API 로그인·가입 및 앱 상태 |
| 마이페이지 | `lib/user/mypage/` | Firebase 프로필 + MySQL 통계/쿠폰/찜/최근 본 상품 |
| 주문 화면 | `lib/order/` | 장바구니·결제·주문/교환/반품·픽업 QR 화면. 데모 상태 및 미연동 흐름이 남아 있음 |
| Flutter 공통 호출 | `lib/services/fitpick_api_service.dart`, `api_client.dart`, `mypage_api.dart` | 공통 세션 토큰과 서버 주소 사용 |
| 통합 서버 | `python/fastapi/main.py` | `/api/*`, `/api/v1/*` 라우터를 한 앱 및 Swagger에 등록 |
| 공통 MySQL | `python/db.py`, `python/fastapi/commerce.py` | `.env` 설정, 파라미터 바인딩, 트랜잭션 |
| Firebase 인증/계정 | `accounts.py`, `firebase_identity.py`, `login.py`, `signup.py`, `dependencies.py` | Auth 비밀번호 검증 및 account 프로필 연결 |
| 고객 SQL API | `python/fastapi/user/`, `discover/` | 마이페이지 및 실제 상품/매장 조회 |
| 본사 SQL/Firebase API | `python/fastapi/headquarters/` | 주문·회원·대리점·계약·문의·리뷰·재고 조회 |
| 서버 로컬 저장 | `python/fastapi/local_store.py` | SQLite 세션·알림·설정. 다른 PC에서 자동 공유되지 않음 |
| ERD/시드 | `docs/erd-design.md`, `lib/models/erd_entities.dart`, `lib/services/erd_*`, `tool/*seed*` | 실서비스 데이터와 혼동하거나 운영에서 자동 실행하지 말 것 |

이 저장소에는 관리자 Pad Flutter 화면 자체가 없다. 본사 API 검사는 가능하지만 Pad 화면 표시와 기기 간 종단간 인증은 검증하지 못했다.

## 실제 데이터 집계

MySQL 행 수:

| 테이블 | 행 | 테이블 | 행 |
| --- | ---: | --- | ---: |
| customer | 9 | product | 11 |
| authorized_dealer | 5 | head_office | 4 |
| purchase | 6 | pickup | 4 |
| p_return | 3 | return | 4 |
| review | 5 | contact | 4 |
| customer_setting | 1 | customer_coupon | 2 |
| coupon | 3 | wishlist | 0 |
| recently_viewed | 0 | notice | 5 |
| banner_image | 3 | model | 4 |
| option | 3 | filming | 4 |
| contract | 5 | contraction | 4 |
| termination | 2 | | |

Firestore: `account` 6, `employee` 2. `change`, `connect`, `distributor_inventory`, `manufactor`, `office_inventory`, `order`, `quotation`, `recieve`, `registration`, `resister`, `send`는 각각 1개 문서. Firebase Auth 사용자는 1명이다.

## 화면에서 필요한 데이터와 실제 저장소 비교

| 화면/업무 | 실제 원본과 현재 확인 결과 | 부족한 데이터/연결 및 처리 |
| --- | --- | --- |
| 가입·로그인 | Auth 1명, account 6명, customer 9명 | Auth 미연결 account 5명. 실제 비밀번호 확인/재설정 없는 일괄 Auth 생성은 하지 않음 |
| 프로필 | account ↔ customer 공통 이메일 3개 | 공통 3개 모두 이름·전화·성별·주소 불일치. account에만 3개, customer에만 6개. 같은 이메일만으로 잘못된 프로필을 덮어쓰지 않고 소유자 확인 필요 |
| 신발 사이즈 | account의 6개 문서 모두 `shoeSize=null` | 화면에서 임의 270mm를 실제 값으로 표시하지 않음. 프로필 저장 전 선택 요구. 가입 폼의 기존 사이즈 선택·검증은 유지 |
| 회원 등급/기본 설정 | customer.totalprice, customer_setting | 설정행 없는 고객 8명. GET 시 가짜 고객/설정 자동 생성하지 않고 LEFT JOIN으로 조회 |
| 상품/색상/사이즈 | product.p_code가 옵션 식별자, p_sku와 브랜드로 관련 옵션 조회 | 색상 목록×사이즈 목록의 임의 조합 금지. 실제 옵션 행의 p_code/가격/이미지를 다음 화면에 전달. 같은 조합이 여러 코드면 선택 확정 차단 |
| 상품 용도 필터 | product에는 용도 관계 없음 | model/option/filming 존재만으로 러닝·데일리 등 용도를 추측하지 않음. 관계 정의 필요 |
| 매장 선택 | authorized_dealer 5개 | 픽업 지점으로만 사용. 대리점 재고로 구매 가능 여부를 판단하지 않음. 검색 후 사라진 선택값 초기화 |
| 구매 리뷰 | review 5개, product와 연결 | 상세 화면 실제 API 조회. review_seq 자동증가/고유 보장 부재, context는 45자. 신규 작성은 409, 수정은 실제 컬럼 길이를 넘으면 409 |
| 고객 문의 | 실제 contact는 c_seq/contact_post/c_answer/c_answerdate/c_status | 고객 API는 contact_seq/context/response/r_date/process를 기대함. 불일치 시 409로 차단. 실제 컬럼을 쓰는 본사 조회는 유지 |
| 쿠폰 | coupon 3개, customer_coupon 2개 | GET의 발급 부작용 분리. 로그인 소유자만 별도 POST 발급. 비정상 유효기간 409. 결제 시 소진/취소 복원 흐름은 별도 미완료 |
| 찜/최근 본 상품 | 테이블 모두 0행 | 빈 결과 정상. 본인 토큰 필수. 상품 상세 진입 시 인증 사용자 최근 조회 기록 호출 연결. 이번 실DB 기록 요청은 미실행 |
| 결제수단 | customer_setting.default_payment | 선호 수단 문자열만 있음. 실제 카드·결제 토큰·PG 승인 정보가 아님 |
| 장바구니/주문·환불·교환 | lib/order에 메모리/데모 흐름 잔존 | 영속 장바구니와 고객 주문 API, 결제·환불·교환 처리/원자성 연동 미완료. 현재 화면을 실거래 완료로 간주하면 안 됨 |
| 수령 준비·QR 인증 | pickup은 고객+대리점 기반 행 | 주문 연결키, 토큰 해시·만료·1회 사용·상태전이·재발급 연결 없음. 안전한 생성/검증 흐름을 임의로 만들지 않음 |
| 본사 재고 | office_inventory 1개, MySQL 상품과 코드 불일치 | 미해결 코드를 `unresolved_product_codes`로 노출. 현재고 부재는 null. 수량 조정은 기존 501 유지 |
| 관리자 계정 | employee 2개 | Auth 연결 2개 누락, employeeId↔head_office.id 2개 불일치. 역할/매핑 승인 필요 |
| 알림/설정 | 서버 SQLite | 주문 이벤트의 공유/영속 알림이 아님. 여러 서버 실행 시 세션/알림/설정 불일치 가능 |

## 우선 해결해야 할 데이터 구조

1. **계정 원본/이관**: account의 레거시 password 필드 5개, customer의 비어 있지 않은 password 6개, employee의 password 필드 1개가 남아 있다. 일반 고객 비밀번호는 Auth에서 검증하도록 보완했지만 기존 값은 이번에 삭제하지 않았다. 기존 Auth 계정에 옛 Firestore 비밀번호로 재인증하는 우회는 차단했다. Auth 미이관 계정은 기존 비밀번호의 정당한 검증 또는 재설정 후 처리해야 한다.
2. **상품 참조**: `office_inventory`, `distributor_inventory`, `registration`, `order`, `recieve`의 각 1개 `productId`가 MySQL product에 없다(총 5개 참조). `quotation`, `send`에는 productId 자체가 없다. 실제 어느 모델/색상/사이즈인지 확인 전 자동 치환 금지.
3. **주문 식별**: purchase PK는 `(customer_customer_id, head_office_id)`이다. 상품·반복 주문을 구분하는 독립 주문/라인 키, 수량, 수령 지점, 결제/상태 연결이 부족하다. p_code는 실제 상품과 모두 일치하지만 DB FK는 아니다.
4. **수령·반품 식별**: pickup 및 p_return PK는 고객+대리점 조합이다. p_return.p_id는 현재 상품과 맞지만 주문 연결로 단정할 수 없다. 반복 수령/환불/교환 이벤트를 안정적으로 식별할 구조가 필요하다.
5. **리뷰·문의 식별**: review의 PK는 고객+상품이며 review_seq는 고유/자동증가가 아니다. 현재 동일 고객 내 review_seq 중복은 0건이지만 미래 중복은 DB가 막지 못한다. contact도 고객+본사 키여서 반복 문의 저장 제약이 있다. 고객/본사 API를 함께 고려해 설계해야 한다.
6. **기본 설정 참조**: customer_setting/wishlist/recently_viewed/customer_coupon에 관계 FK가 없다. 코드 검증만으로 외부 수정에 의한 고아 데이터를 막을 수 없다. 이번에는 제약을 추가하지 않았다.
7. **문자열 저장 길이**: customer의 주요 문자열은 varchar(45)이다. 긴 주소·이메일 등 API 입력 허용 범위와 SQL 용량의 조정이 남아 있다. 실패 시 동기화 미완료를 처리해야 하며 임의 절삭해서는 안 된다.

DDL은 적용하지 않았다. 특히 문의의 기존 컬럼을 새 이름으로 단순 변경하면 본사 API가 깨진다. 먼저 주문/문의 키와 이관 정책을 합의한 다음 별도 마이그레이션이 필요하다.

## 잉여/중복 후보 — 삭제 확정 아님

- customer.password와 employee/account의 레거시 password: Auth 이관 및 모든 소비 코드 확인 후 제거 후보. 현재 값은 보존했다.
- customer_setting.shoe_size와 account.shoeSize: 고객 사이즈의 원본을 account로 통일하고 구형 SQL 값은 호환 조회만 유지. 신규 고객 API 직접 사이즈 쓰기는 차단했다.
- account와 customer 프로필: 단순 잉여가 아니라 인증 프로필/상거래 FK를 위한 미러 역할. 양방향 무조건 덮어쓰기 대신 원본과 동기화 실패 정책이 필요하다.
- Firestore `order`는 제조사 발주, MySQL `purchase`는 고객 구매다. 같은 주문이라는 이유로 합치거나 삭제하면 안 된다.
- `resister`와 `registration`은 회원 등록 이력/재고 등록 관계로 서로 다른 용도다. `manufactor`, `recieve`, `resister`의 오탈자도 실제 소비 코드가 있어 일괄 이름 변경하지 않았다.
- `connect`/`change`/`resister`의 시드 이력, `lib/services/erd_seed_service.dart` 및 seed 도구는 실사용 경로 정리 후보다. 실데이터인지 확인 전 삭제하지 않았다.
- banner_image/model/option/filming/notice 등은 Discover에서 충분히 쓰지 않는다고 전체 앱에서 불필요한 테이블로 판정할 수 없다. 데이터는 보존했다.

## 이번 이어서 작업의 코드 변경

- `python/fastapi/user/main.py`: 마이페이지·결제수단·쿠폰·찜·최근조회에 토큰 및 본인 소유자 검사, 쿠폰 발급 POST 분리, 사이즈 저장 경로 통일.
- `python/fastapi/user/mypage_data.py`: 읽기 요청의 고객/설정 생성 제거, 없는 설정 허용, 이미지 URL 수정, 쿠폰 유효기간 검사.
- `python/fastapi/main.py`: 통합 앱에 MyPageError 처리 등록.
- `python/fastapi/accounts.py`, `login.py`, `firebase_identity.py`: 기존 Auth 사용자 레거시 비밀번호 우회 차단, Auth 기반 비밀번호 변경, UID 불일치 차단, 비정상 Firebase 응답 처리.
- `python/fastapi/schema_guard.py`(추가), `customer_support.py`, `review_write.py`, `review_management.py`: 실제 스키마/길이를 확인하고 지원 불가 요청은 409 처리.
- `python/fastapi/discover/repository.py`, `router.py`, `schemas.py`: 실제 옵션 행 반환, 옵션 코드 유지, 가격 파싱 오류 명시.
- `python/fastapi/headquarters/inventory.py`, `schemas.py`: 연결되지 않은 재고 상품코드 별도 반환.
- `lib/services/api_client.dart`, `fitpick_api_service.dart`, `mypage_api.dart`: 공통 인증 헤더, 401 토큰 폐기, 응답 파싱 오류 처리, `/api/v1` 경로 일치.
- `lib/user/mypage/mypage_controller.dart`, `mypage_loader.dart`, `mypage_models.dart`, `my_page.dart`, `profile_page.dart`: 계정 전환 시 이전 데이터 폐기, 로딩/오류/재시도, nullable 사이즈 및 미선택 저장 방지.
- `lib/discover/discover_api.dart`, `product_detail_page.dart`: 실제 리뷰 조회, 최근조회 호출, 실제 옵션 전달, 지연 리뷰 요청 오류 처리, 클라이언트 정리.
- `lib/discover/product_list_page.dart`, `store_selection_page.dart`: 조건문 정리, 검색 후 선택 초기화, RadioGroup 전환 및 클라이언트 정리.
- `lib/order/checkoutPage.dart`: deprecated RadioListTile 속성을 RadioGroup으로 이전. 결제 업무 로직은 변경하지 않음.
- `python/fastapi/tests/test_api.py`, `test_data_contracts.py`(추가), `test/mypage_loader_test.dart`(추가), `test/live_api_connection_test.dart`: 스키마·권한·부작용·계정 전환 회귀 검사 및 import 정리.
- `tool/audit_data_contracts.py`(추가), 본 보고서/JSON: 재실행 가능한 읽기 전용 실데이터 감사.

기존 미커밋 파일의 수정과 이번 추가 수정이 함께 있으므로 `git diff` 전체를 이번 작업만의 변경으로 해석하지 말 것.

## 테스트 결과 및 한계

| 검사 | 결과 | 의미/제한 |
| --- | --- | --- |
| `python3 -m pytest python/fastapi/tests -q` | 51 통과 | 모의 데이터/의존성 기반. 실제 가입/구매 테스트 아님 |
| `flutter test` | 11 통과, 2 생략 | 회원가입/토큰/모델, 계정 전환 늦은 응답 폐기, 재시도 테스트. 실제 로그인용 live 테스트 2개는 미실행 |
| `flutter analyze` | error/warning 없음, 기존 파일명 info 12개 | 종료코드 1: info도 실패로 취급하는 기본 설정. 전체 green이라고 표시하지 않음 |
| 실제 MySQL/Firebase API 조회 | 23개 GET 중 22개 200, 고객 문의 1개 예상 409 | 실제 데이터 조회·직렬화. 쓰기 SQL 차단, 인증 의존성은 대체. 실제 사용자/관리자 로그인 검증 아님 |
| 실제 스키마 검사 | 불일치 7개, 종료코드 1 | review 길이/자동증가 2개, contact 기대 컬럼 누락 5개. 결함을 숨기지 않고 미완료로 유지 |
| 변경 전후 데이터 확인 | MySQL 23개 전체 지문 동일 | 이번 검사 중 업무 데이터 변경 없음. Firestore는 문서/필드 집계 동일 |
| `git diff --check` | 통과 | 공백/패치 오류 없음 |

실데이터 200 확인 영역: `/docs`, `/openapi.json`, `/api/v1/test/status`, `/api/v1/test/firebase`, Discover 상품 목록·상세·리뷰·수령 매장, 마이페이지 요약·프로필·결제수단·쿠폰·찜·최근조회, 본사 주문·회원·대리점·계약·문의·리뷰·재고, 내 리뷰 목록. 본사 재고의 미해결 상품 1개도 진단 응답으로 확인했다.

실제 회원가입/MySQL 미러 쓰기, 구매·결제·환불·교환, 관리자 수령 준비, QR/난수 발급·소비, Pad 화면, 여러 기기 간 동기화는 **검증 완료하지 않았다**. 관리자 코드/주문 스키마/인증 매핑을 확보한 뒤 별도 테스트 데이터와 승인된 쓰기 범위로 검증해야 한다.

## 재검증 명령

저장소 루트에서 실행한다. 127.0.0.1은 MySQL이 이 Mac에 실행 중일 때만 사용한다.

```sh
DB_HOST=127.0.0.1 python3 -m tool.audit_data_contracts
DB_HOST=127.0.0.1 python3 -m python.fastapi.check_schema
python3 -m pytest python/fastapi/tests -q
flutter test
flutter analyze
```

API 실행 예시(서버 포트와 MySQL 포트는 별개):

```sh
DB_HOST=127.0.0.1 python3 -m uvicorn python.fastapi.main:app --host 0.0.0.0 --port 8000
```

같은 Mac: `http://127.0.0.1:8000/docs`. 팀원: 같은 LAN에서 `http://<이 Mac의 현재 LAN IP>:8000/docs` 및 앱의 기존 `API_BASE_URL` 설정. MySQL `DB_PORT`는 기존 DB 포트 설정을 그대로 사용하며 Swagger를 3306에 연결하지 않는다. 서비스 계정 JSON이나 DB 비밀번호는 Flutter에 포함하지 않는다.

환경변수 범주: MySQL `DB_HOST/DB_PORT/DB_USER/DB_PASSWORD/DB_NAME`, Firebase `FIREBASE_PROJECT_ID/FIREBASE_DATABASE_ID/GOOGLE_APPLICATION_CREDENTIALS`, 인증 Web API 키의 기존 설정, 앱 `API_BASE_URL`, 서버 `API_SQLITE_PATH/API_SESSION_SECONDS/API_CORS_ORIGINS`, 고객센터 `SUPPORT_HEAD_OFFICE_ID`. 실제 키 이름·우선순위는 `.env.example` 및 각 로딩 모듈을 기준으로 사용하고 민감값은 Git에 올리지 않는다.
