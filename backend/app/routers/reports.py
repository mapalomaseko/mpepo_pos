"""Reporting endpoints."""
from __future__ import annotations

from datetime import datetime, date
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from .. import crud, schemas
from ..deps import get_db

router = APIRouter()


@router.get("/daily", response_model=schemas.DailyReport)
def daily_report(date_param: Optional[str] = Query(None, alias="date"), db: Session = Depends(get_db)):
    """Return aggregate totals for a given day."""

    if date_param:
        try:
            target_date = datetime.strptime(date_param, "%Y-%m-%d").date()
        except ValueError as exc:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid date format") from exc
    else:
        target_date = datetime.utcnow().date()

    report = crud.daily_report(db, target_date)
    return report
