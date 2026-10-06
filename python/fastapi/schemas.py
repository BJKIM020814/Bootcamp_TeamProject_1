# API 계약: 프론트 요청의 필드/길이/타입을 검증하고 Swagger에 응답 구조를 표시한다.
from typing import Optional, Literal
from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator


class Input(BaseModel):
    # 알 수 없는 요청 필드를 거부해 소유자 이메일 같은 임의 필드가 쓰기 작업에 섞이지 않게 한다.
    model_config = ConfigDict(extra='forbid', str_strip_whitespace=True)


class LoginInput(Input):
    # 비밀번호의 앞뒤 공백도 원문의 일부이므로 문자열 자동 trim을 끈다.
    email: EmailStr
    # 공백도 비밀번호의 일부이므로 전역 strip을 덮어쓴다.
    password: str = Field(min_length=1, max_length=128)

    model_config = ConfigDict(extra='forbid', str_strip_whitespace=False)


class SignupInput(LoginInput):
    # 회원 ERD 필드에 약관 동의와 선택 나이를 더한 가입 요청 계약이다.
    password: str = Field(min_length=8, max_length=128)
    name: str = Field(min_length=1, max_length=45)
    phoneNumber: str = Field(pattern=r'^01[0-9]-?[0-9]{3,4}-?[0-9]{4}$')
    gender: Literal['선택 안 함', '여성', '남성', '기타'] = '선택 안 함'
    address: str = Field(min_length=1, max_length=200)
    signupPath: Literal['이메일'] = '이메일'
    age: Optional[int] = Field(default=None, ge=0, le=130)
    shoeSize: int = Field(ge=220, le=310, multiple_of=5, strict=True)
    agreed: Literal[True]

    @field_validator('name', 'address')
    @classmethod
    def nonblank(cls, value):
        # 길이가 있는 문자열이라도 공백뿐이면 이름/주소로 저장하지 않는다.
        if not value.strip():
            raise ValueError('공백만 입력할 수 없습니다.')
        return value.strip()


class ReviewFields(Input):
    # 리뷰 작성/수정에서 공유하는 입력이다. 기존 화면과 동일하게 내용은 최소 10자다.
    content: str = Field(min_length=10, max_length=2000)
    rating: int = Field(ge=1, le=5, strict=True)
    fit: Literal['작아요', '정사이즈', '커요'] = '정사이즈'


class ReviewCreate(ReviewFields):
    # 신규 리뷰에만 상품 연결 키가 필요하다. 수정 요청에서는 상품 코드를 받지 않는다.
    productCode: str = Field(min_length=1, max_length=45)


class SettingsPatch(Input):
    # 전달하지 않은 항목과 false를 구분하여 일부 설정만 바꿀 수 있다.
    orderNotification: Optional[bool] = Field(default=None, strict=True)
    marketingNotification: Optional[bool] = Field(default=None, strict=True)

    @field_validator('orderNotification', 'marketingNotification')
    @classmethod
    def no_null(cls, value):
        # 설정의 생략은 허용하지만 명시적인 null은 차단해 참/거짓만 저장한다.
        if value is None:
            raise ValueError('설정은 true 또는 false여야 합니다.')
        return value


class ContactCreate(Input):
    # 레거시 contact의 45자 필드와 분리한 문의 테이블에 본문을 보관한다.
    content: str = Field(min_length=1, max_length=2000)

    @field_validator('content')
    @classmethod
    def contact_not_blank(cls, value):
        if not value.strip():
            raise ValueError('문의 내용을 입력해 주세요.')
        return value.strip()


class ContactMessageCreate(Input):
    """회원이 기존 문의 대화에 추가하는 후속 메시지."""
    content: str = Field(min_length=1, max_length=2000)

    @field_validator('content')
    @classmethod
    def message_not_blank(cls, value):
        if not value.strip():
            raise ValueError('메시지를 입력해 주세요.')
        return value.strip()


# 응답 모델은 Swagger에서 프론트가 필드/타입을 확인할 수 있도록 제공한다.
from datetime import datetime
from typing import Generic, TypeVar

T = TypeVar('T')


class Page(BaseModel, Generic[T]):
    # 목록 API의 공통 응답이며 items의 타입은 리뷰/상품/문의 등 각 페이지에 맞게 지정한다.
    items: list[T]
    total: int
    limit: int
    offset: int


class AccountOut(BaseModel):
    # 회원 응답에는 비밀번호를 정의하지 않아 프론트로 전달되지 않는다.
    email: str
    name: str
    phoneNumber: str
    gender: str
    address: str
    signupPath: str
    age: Optional[int] = None
    shoeSize: Optional[int] = None


class AccountProfilePatch(Input):
    # 이메일은 Firebase Auth의 식별자이므로 이 화면에서 변경하지 않는다.
    name: str = Field(min_length=1, max_length=45)
    phoneNumber: str = Field(pattern=r'^01[0-9]-?[0-9]{3,4}-?[0-9]{4}$')
    shoeSize: int = Field(ge=220, le=310, multiple_of=5, strict=True)

    @field_validator('name')
    @classmethod
    def profile_name_nonblank(cls, value):
        if not value.strip():
            raise ValueError('공백만 입력할 수 없습니다.')
        return value.strip()


class SessionOut(BaseModel):
    # 토큰 원문은 로그인 응답으로만 전달하며 expiresAt은 Unix 초 단위다.
    accessToken: str
    tokenType: Literal['bearer']
    expiresAt: int
    account: AccountOut


class SignupOut(SessionOut):
    # MySQL 연결이 늦어진 경우 프론트가 후속 연결 요청을 할 수 있도록 결과를 구분한다.
    customerSynced: bool
    nextAction: Optional[str]


class ReviewOut(BaseModel):
    # 리뷰와 상품을 조인한 결과를 프론트용 이름으로 반환한다.
    id: int
    productCode: str
    productName: str
    brand: str
    content: str
    rating: float
    fit: str
    createdAt: datetime
    likeCount: int


class ReviewableOut(BaseModel):
    # 리뷰작성 화면에서 구매 상품을 선택할 때 필요한 필드만 제공한다.
    productCode: str
    productName: str
    brand: str


class ContactOut(BaseModel):
    # 문의의 전체 대화와 마지막 답변 요약을 함께 반환한다.
    id: int
    content: str
    createdAt: datetime
    response: Optional[str]
    respondedAt: Optional[datetime]
    process: int
    messages: list['ContactMessageOut'] = Field(default_factory=list)


class ContactMessageOut(BaseModel):
    id: Optional[int] = None
    authorRole: Literal['customer', 'employee']
    authorId: str
    content: str
    createdAt: datetime
    turnIndex: int


class SettingsOut(BaseModel):
    # 기존 설정 화면의 두 스위치 및 앱 버전에 대응한다.
    orderNotification: bool
    marketingNotification: bool
    appVersion: str


class NotificationOut(BaseModel):
    # 알림 한 건의 응답이다. readAt이 null이면 아직 읽지 않았다.
    id: int
    category: str
    title: str
    body: str
    createdAt: datetime
    readAt: Optional[datetime]


class NotificationPage(Page[NotificationOut]):
    # 알림 목록은 공통 페이지 정보에 배지 표시용 unreadCount를 추가한다.
    unreadCount: int


class PasswordChange(Input):
    # 새 로그인과 동일하게 비밀번호 공백을 보존한다.
    model_config = ConfigDict(extra='forbid', str_strip_whitespace=False)
    current: str = Field(min_length=1, max_length=128)
    next: str = Field(min_length=8, max_length=128)
