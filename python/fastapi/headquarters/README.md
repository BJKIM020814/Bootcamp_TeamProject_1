# FITPICK 본사 API

모든 경로는 기존 `python.fastapi.main:app`에 등록되며 prefix는 `/api/v1/headquarters`입니다. DB 접속은 공통 `python/db.py`를 재사용합니다.

## 인증과 권한

기존 로그인 bearer 토큰을 보내야 합니다. 본사 권한은 토큰의 이메일과 Firestore `employee.email`을 서버에서 조회해 직원 ID·직급·부서를 결정합니다. 현재 직원 seed에는 이메일이 없어 HQ 요청은 기본적으로 403으로 거부됩니다. 배포 전 직원 문서와 회사 계정을 안전하게 연결해야 하며, 클라이언트가 보낸 employee ID나 직급은 권한 판단에 사용하지 않습니다. 기존 테스트 직원 `대리`는 결재 권한이 없습니다. 직원 비밀번호만 있는 별도 로그인 경로는 기존 세션 체계와 연결되어 있지 않아 추가하지 않았습니다.

## API

| 화면 | 메서드·경로 | 데이터 |
|---|---|---|
| 주문관리 | `GET /api/v1/headquarters/orders` | 결제 직후 생성되는 `purchase_order` + `purchase_order_item` + 상품 |
| 주문 상세 | `GET /api/v1/headquarters/orders/by-number/{order_number}` | 주문번호로 주문의 모든 상품 줄 조회 |
| 재고관리 | `GET /api/v1/headquarters/inventory` | Firestore `office_inventory` + MySQL `product` |
| 재고 조정 | `POST /api/v1/headquarters/inventory/{product_code}/adjustments` | 현재고 기준/상품 연결 입출고 원장이 없어 501 |
| 결재관리 | `GET, POST /api/v1/headquarters/approvals` | Firestore `procurement_approval` (신규 API 소유 컬렉션) |
| 결재 처리 | `PATCH /api/v1/headquarters/approvals/{approval_id}/decision` | 팀장 승인/반려, 이후 이사 단계 |
| 판매관리 | `GET /api/v1/headquarters/sales/summary?start=...&end=...&group_by=day%7Cproduct` | MySQL purchase에서 환불(`p_return.refund=1`) 제외 |
| 대리점관리 | `GET /api/v1/headquarters/branches?seoul_only=true` | MySQL `authorized_dealer` |
| 대리점 상세 | `GET /api/v1/headquarters/branches/{branch_id}` | MySQL `authorized_dealer.seq` |
| 계약관리 | `GET /api/v1/headquarters/contracts` | MySQL `contract`, `contraction`, `model`, `termination` |
| 계약 상세 | `GET /api/v1/headquarters/contracts/{head_office_id}/{model_id}/{contract_sequence}` | 계약 복합키 |
| 문의 답변 | `PATCH /api/v1/headquarters/inquiries/answer?customer_id=...&head_office_id=...&c_seq=...` | JSON `{"answer":"답변 내용"}`; `inquiry_message`에 새 대화 turn 추가 |

요청에서 쓸 주문 ID는 별도 컬럼이 없어서 복합키이며, 값은 목록 조회에서 얻습니다. Swagger 문서의 schemas와 각 경로 summary를 참고하세요. 조회 응답은 실제 행만 반환하며 빈 테이블은 빈 `items`입니다.

## 확인된 제약 / 데이터 작업 필요

- 주문 접수 즉시 관리자 주문 목록에 보이도록 `purchase_order` 계열 테이블을 주문 원본으로 사용합니다. 레거시 `purchase`는 고객+본사 복합 기본키라 반복 주문/여러 상품을 안전하게 기록할 수 없으며, 수령 완료 시 리뷰/구매 이력 호환용으로만 반영됩니다.
- 배송 상세 상태는 별도 배송 관계가 없어 아직 제공하지 않습니다. 픽업 진행 상태·수량·대리점·결제수단은 `purchase_order`, `purchase_order_item`, `purchase_order_detail`에서 조회합니다.
- 환불 집계는 구매 회원 ID와 `p_return.p_id = purchase.p_code` 및 `refund=1`을 이용합니다. 반품 스키마에 주문/head-office 키가 없어 같은 고객의 동일 상품 재구매 건을 구별할 수 없습니다. 정확한 주문 단위 환불 차감에는 주문 ID 관계가 필요합니다.
- `office_inventory`에는 최소수량만 있고 검증된 현재고 수량이 없습니다. `registration`은 재고 수량 기록, `recieve`는 입고 수량, `send`는 수량을 가지나 `send`에 productId가 없습니다. 그러므로 현재고 숫자/발주 필요 여부는 기준수량·원장 의미가 확정된 상품만 계산되어야 합니다. 현재 응답은 미설정이면 null입니다.
- 결재 컬렉션은 기존 ERD에 없어 이 API가 `procurement_approval`을 새로 소유합니다. 견적 `quotation`에는 상품코드와 제조사 ID 연결이 보장되지 않아 안전한 품의 생성/최종 발주가 차단될 수 있습니다. 견적 레코드에 `productId`, `manufacturerId`를 연결해야 합니다. 최종승인 시 중복 없는 발주 생성도 이 관계가 먼저 필요합니다.
- 반려된 품의를 수정·재상신하는 정책은 구현하지 않았습니다. 새 품의 생성을 재상신으로 볼지 기존 품의를 재개할지 정책 결정이 필요합니다.
- `purchase`에 대리점 키가 없어 대리점별 매출 및 판매 수량은 제공되지 않습니다. Naver 지도 키가 없으면 지도는 미연결이며 조회 결과에 좌표가 없는 대리점의 가상 좌표를 만들지 않습니다.
- 계약은 실제 계약/종료 행 조회만 구현했습니다. 신규/수정/종료 입력 규칙, 계약 상태의 기간 계산 기준, 위약금 산식은 스키마만으로 확정할 수 없어 쓰기 기능은 노출하지 않습니다.

## 실행 및 팀원 접속

프로젝트 루트에서 기존 가상환경과 `.env`를 사용합니다. `DB_HOST/DB_PORT`는 MySQL 대상(현재 설정 192.168.20.68:3306)이고 `API_HOST/API_PORT`는 FastAPI 바인딩 주소/포트(기본 실행 예시는 0.0.0.0:8000)입니다.

```sh
source .venv/bin/activate
uvicorn python.fastapi.main:app --reload --host 0.0.0.0 --port 8000
```

같은 네트워크 팀원은 `http://<개발자-LAN-IP>:8000/docs`로 접속합니다. 방화벽과 `API_CORS_ORIGINS`, MySQL 네트워크 ACL 및 Firebase 서비스 계정 권한을 각자 환경에 맞게 열어야 합니다. 서버를 공용 네트워크에 그대로 노출하지 마세요.

`.env`에 Firebase `GOOGLE_APPLICATION_CREDENTIALS`, `FIREBASE_PROJECT_ID=shoe-20260930`, `FIREBASE_DATABASE_ID=(default)`가 구성되어야 합니다. 본사 기능은 기존 고객 로그인만으로 접근할 수 없고, employee.email을 계정과 연결하는 데이터 작업이 선행됩니다.
