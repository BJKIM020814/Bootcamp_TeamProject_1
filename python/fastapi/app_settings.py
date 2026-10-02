# 주문/마케팅 알림 설정은 회원 이메일별로 서버 SQLite에 영구 저장한다.
"""4. 앱설정: 로그인한 회원의 알림 설정 저장."""
import os
from fastapi import APIRouter, Depends
from .dependencies import current_email, get_local
from .schemas import SettingsPatch, SettingsOut

router = APIRouter(prefix='/settings', tags=['4. 앱설정'])


@router.get('', response_model=SettingsOut)
def get_settings(email=Depends(current_email), local=Depends(get_local)):
    # 저장된 설정이 없으면 주문 true, 마케팅 false 기본값으로 시작한다.
    return {**local.settings(email), 'appVersion': os.getenv('APP_VERSION', '1.0.0')}


@router.patch('', response_model=SettingsOut)
def update_settings(data: SettingsPatch, email=Depends(current_email), local=Depends(get_local)):
    # PATCH에서 실제로 전달된 항목만 저장한다. 누락된 설정을 기본값으로 덮어쓰지 않는다.
    return {**local.update_settings(email, data.model_dump(exclude_unset=True)),
            'appVersion': os.getenv('APP_VERSION', '1.0.0')}
