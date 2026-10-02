# 알림 생성은 서버 이벤트가 담당하고, 회원은 자신의 목록 조회와 읽음 처리만 할 수 있다.
"""3. 알림: 서버 이벤트로 저장된 내 알림 조회 및 읽음 처리."""
from fastapi import APIRouter, Depends, HTTPException, Query
from .dependencies import current_email, get_local
from .schemas import NotificationPage

router = APIRouter(prefix='/notifications', tags=['3. 알림'])


@router.get('', response_model=NotificationPage)
def list_notifications(limit: int = Query(20, ge=1, le=100), offset: int = Query(0, ge=0),
                       email=Depends(current_email), local=Depends(get_local)):
    # 내 알림과 전체 개수, 미읽음 개수를 반환해 목록과 배지를 함께 표시할 수 있게 한다.
    return local.notifications(email, limit, offset)


@router.patch('/read-all')
def read_all(email=Depends(current_email), local=Depends(get_local)):
    # 로그인 회원의 미읽음 알림만 처리하고 변경된 개수를 반환한다.
    return {'updatedCount': local.read_all(email)}


@router.patch('/{notification_id}/read')
def read_one(notification_id: int, email=Depends(current_email), local=Depends(get_local)):
    # 알림 ID와 소유자 이메일을 함께 확인한다. 다른 회원 알림은 읽음 처리하지 않는다.
    if not local.read_notification(email, notification_id):
        raise HTTPException(404, '알림을 찾을 수 없습니다.')
    return {'id': notification_id, 'isRead': True}
