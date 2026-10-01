# 첨부 ERD와 연결된 Firestore의 1:1 매핑

대상: `shoe-20260930` / `(default)` / STANDARD / asia-northeast3.
사진의 사각형 엔티티 6개와 마름모 관계 7개를 각각 컬렉션으로 사용한다.
사진에 없는 상품 컬렉션은 만들지 않는다. 제품 ID는 본사재고 및 관계 문서의 필드다.

## 13개 컬렉션

| 사진 | 기존 Firebase 컬렉션 | 필드 |
|---|---|---|
| 회원 | `account` | 이메일 (`email`), password (`password`), 전화번호 (`phoneNumber`), 이름 (`name`), 성별 (`gender`), 주소 (`address`), 가입경로 (`signupPath`) |
| 직원(본사 서버) | `employee` | 직원 ID (`employeeId`), 직원 password (`password`), 직급 (`position`), 부서 (`department`), 사업자번호 (`businessNumber`) |
| 제조사 | `manufactor` | 제조사 ID (`manufacturerId`), 제조사명 (`manufacturerName`), 주소 (`address`) |
| 견적서 | `quotation` | 공급가 (`supplyPrice`), 상품명 (`productName`), 단가 (`unitPrice`), 수량 (`quantity`), seq (`seq`), 날짜 (`quotedAt`), 담당자명 (`managerName`) |
| 대리점재고 | `distributor_inventory` | 지점명 (`branchName`), 대리점재고 (`quantity`), 제품 ID (`productId`) |
| 본사재고 | `office_inventory` | 제품 ID (`productId`), 최소수량 (`minimumQuantity`) |
| 접속하다 (관계) | `connect` | 회원 이메일 (`email`), 직원 ID (`employeeId`), 접속일자 (`connectedAt`), 접속위치 (`accessLocation`), IP 주소 (`ipAddress`) |
| 변경하다 (관계) | `change` | 회원 이메일 (`email`), 직원 ID (`employeeId`), 변경일자 (`changedAt`) |
| 등록하다 (관계) | `resister` | 회원 이메일 (`email`), 직원 ID (`employeeId`), 등록일자 (`registeredAt`) |
| 수주하다 (관계) | `recieve` | 직원 ID (`employeeId`), 제조사 ID (`manufacturerId`), 수주일 (`receivedAt`), 수주량 (`quantity`), 제품 ID (`productId`) |
| 발주하다 (관계) | `order` | 직원 ID (`employeeId`), 제조사 ID (`manufacturerId`), 견적서 seq (`quotationSeq`), 제품 ID (`productId`), 발주일 (`orderedAt`), 발주량 (`quantity`) |
| 재고를 발송하다 (관계) | `send` | 직원 ID (`employeeId`), 지점명 (`branchName`), 발송수량 (`quantity`), 발송일 (`sentAt`), 수령여부 (`isReceived`) |
| 재고를 등록하다 (관계) | `registration` | 직원 ID (`employeeId`), 제품 ID (`productId`), 재고 현황 (`quantity`), 브랜드명 (`brandName`), 재고등록일 (`registeredAt`) |

기존 이름 `manufactor`, `resister`, `recieve`는 철자를 임의로 바꾸지 않았다.
`quotation`은 빠져 있던 견적서를 추가한 이름이다.
관계 문서의 email, employeeId, manufacturerId, branchName, productId, quotationSeq는 연결 키다.
사진에 있는 식별자 값으로 연결하고 기존 Firebase 문서 ID는 보존한다.
예: `order.quotationSeq → quotation.seq`, `registration.productId → office_inventory.productId`.
Firestore는 이 연결을 외래 키 제약으로 자동 강제하지 않는다.

## 원격 정리 내용

- 사진에 없는 `login/LOGIN-001`, `changepassword/PWD-001` 테스트 문서 삭제.
- `quotation/QUO-001` 생성.
- 직원: department, businessNumber 추가.
- 제조사: address 추가.
- 대리점재고: productId 추가.
- 발주: quotationSeq 연결 키 추가.
- 발송: isReceived 추가.
- 기존 12개 컬렉션의 문서 ID와 기존 필드 값 보존.

추가 값은 기존 문서와 같은 개발용 예시다. businessNumber는 실제 사업자번호가 아닌 명시적인 테스트 문자열이다.
회원 및 직원의 password는 사진과 기존 테스트 DB에 있는 필드로 보존하며 화면에서는 마스킹한다.
현재 원격 보안 규칙은 테스트용 전체 읽기/쓰기 허용 상태이고 인증 기능은 구현되어 있지 않다.
`firestore.rules`는 실제 배포된 내용을 가져온 것이며 이번 작업에서 권한을 새로 배포하지 않는다.
실제 비밀번호나 개인정보를 이 테스트 DB에 입력하면 안 된다.

## 코드 및 실행

- `lib/models/erd_entities.dart`: 13개 컬렉션/한글 필드명 및 Firestore 변환.
- `lib/services/erd_service.dart`: 선택한 컬렉션의 실시간 조회.
- `lib/discover/home.dart`: StatefulWidget 기본 화면(AppBar와 빈 body).
- `lib/firebase_options.dart`: 웹/iOS/Android별 Firebase 초기화 설정.
- `android/app/google-services.json`: 등록된 Android Firebase 앱 설정.
- `android/settings.gradle.kts`, `android/app/build.gradle.kts`: Google services 플러그인 설정.
- `ios/Flutter/Debug.xcconfig`, `ios/Flutter/Release.xcconfig`: 최소 iOS 15.0 및 Firebase 링크 설정(Profile은 Release 설정 사용).
- `tool/erd_seed.json`: 앱과 관리 도구가 함께 사용하는 13개 테스트 문서.
- `lib/services/erd_seed_service.dart`: SEED_ERD=true일 때 없는 문서만 생성.
- `tool/apply_erd_seed.rb`: 기존 테스트 데이터 검증, 백업, 필드 보완 및 삭제.

관리 도구 사용:

```sh
firebase firestore:databases:list --project shoe-20260930
ruby tool/apply_erd_seed.rb --plan
ruby tool/apply_erd_seed.rb --apply
ruby tool/apply_erd_seed.rb --verify
```

도구는 Firebase CLI 로그인 토큰을 메모리에서만 사용하며 로그에 출력하지 않는다.
허용된 테스트 문서 외에 다른 컬렉션, 문서, 하위 컬렉션, 예상과 다른 필드 값이 발견되면 중단한다.
원격 변경 직전 `tool/backups/before-erd-*.json`에 모든 기존 문서와 배포된 규칙을 저장한다.
백업은 Git에서 제외되고 파일 권한은 0600이다.
변경은 문서 updateTime 조건을 포함한 하나의 commit으로 수행한다.
삭제된 두 테스트 문서는 이 백업의 name/fields를 이용해 복구할 수 있다.
`--verify`는 원격 컬렉션 목록과 문서의 모든 필드를 시드와 비교한다.

REST 작업은 [Firebase 공식 commit API](https://firebase.google.com/docs/firestore/reference/rest/v1/projects.databases.documents/commit)를 따른다.
