"""Registered Seoul pickup branches backed by MySQL authorized_dealer."""

import os
from fastapi import APIRouter, Depends, HTTPException, Query
from python import db
from ..dependencies import current_headquarters_employee
from .schemas import BranchItem, BranchPage

router = APIRouter(prefix='/api/v1/headquarters/branches', tags=['본사 · 대리점관리'])
_SELECT = 'seq AS id,name,dealer_number,manager,address,lat AS latitude,lng AS longitude'


@router.get('', response_model=BranchPage, summary='등록 대리점 목록 조회', description='authorized_dealer에 저장된 실제 행만 반환합니다. 주소 기준 서울 대리점 필터를 제공합니다.')
def branches(seoul_only: bool = Query(False), _employee=Depends(current_headquarters_employee)):
    where = " WHERE address LIKE '서울%'" if seoul_only else ''
    rows = db.query('SELECT ' + _SELECT + ' FROM authorized_dealer' + where + ' ORDER BY seq')
    return BranchPage(items=rows, total=len(rows), naver_map_configured=bool(os.getenv('NAVER_MAP_CLIENT_ID')))


@router.get('/{branch_id}', response_model=BranchItem, summary='대리점 상세 조회')
def branch_detail(branch_id: int, _employee=Depends(current_headquarters_employee)):
    row = db.query_one('SELECT ' + _SELECT + ' FROM authorized_dealer WHERE seq=%s', (branch_id,))
    if row is None:
        raise HTTPException(404, '대리점을 찾을 수 없습니다.')
    return row
