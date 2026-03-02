"""
Shows endpoints
Create and manage card show appearances
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import Optional, List
from datetime import date, datetime
from decimal import Decimal
from pydantic import BaseModel
import uuid

import models
from database import get_db
from auth import get_current_user

router = APIRouter(prefix="/shows", tags=["Shows"])

# ── Schemas ───────────────────────────────────────────────────────────────────

class ShowCreate(BaseModel):
    show_name: str
    show_date: date
    location: Optional[str] = None
    venue: Optional[str] = None
    table_number: Optional[str] = None
    table_cost: Optional[Decimal] = None
    notes: Optional[str] = None

class ShowUpdate(BaseModel):
    show_name: Optional[str] = None
    show_date: Optional[date] = None
    location: Optional[str] = None
    venue: Optional[str] = None
    table_number: Optional[str] = None
    table_cost: Optional[Decimal] = None
    notes: Optional[str] = None

class ShowResponse(BaseModel):
    show_id: str
    show_name: str
    show_date: date
    location: Optional[str]
    venue: Optional[str]
    table_number: Optional[str]
    table_cost: Optional[Decimal]
    notes: Optional[str]
    is_active: Optional[bool]
    created_at: Optional[datetime]

    class Config:
        from_attributes = True

class ShowSummaryResponse(BaseModel):
    """Show detail with P&L summary"""
    show: ShowResponse
    total_sales: Decimal
    total_expenses: Decimal
    net_profit: Decimal
    transaction_count: int

# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.get("/", response_model=List[ShowResponse])
def list_shows(
    active_only: bool = False,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """List all shows for the current user."""
    query = db.query(models.Show).filter(
        models.Show.user_id == current_user.user_id
    )
    if active_only:
        query = query.filter(models.Show.is_active == True)

    return query.order_by(models.Show.show_date.desc()).all()


@router.post("/", response_model=ShowResponse, status_code=201)
def create_show(
    show: ShowCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Create a new show."""
    db_show = models.Show(
        show_id=str(uuid.uuid4()),
        user_id=current_user.user_id,
        is_active=True,
        **show.model_dump()
    )
    db.add(db_show)
    db.commit()
    db.refresh(db_show)
    return db_show


@router.get("/{show_id}", response_model=ShowSummaryResponse)
def get_show(
    show_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Get show detail with P&L summary."""
    show = db.query(models.Show).filter(
        models.Show.show_id == show_id,
        models.Show.user_id == current_user.user_id
    ).first()

    if not show:
        raise HTTPException(status_code=404, detail="Show not found")

    # Calculate P&L
    sales_result = db.query(
        func.coalesce(func.sum(models.InventoryTransaction.total_amount), 0)
    ).filter(
        models.InventoryTransaction.user_id == current_user.user_id,
        models.InventoryTransaction.show_name == show.show_name,
        models.InventoryTransaction.transaction_type == "sale"
    ).scalar()

    expenses_result = db.query(
        func.coalesce(func.sum(models.Expense.amount), 0)
    ).filter(
        models.Expense.user_id == current_user.user_id,
        models.Expense.show_id == show_id
    ).scalar()

    transaction_count = db.query(models.InventoryTransaction).filter(
        models.InventoryTransaction.user_id == current_user.user_id,
        models.InventoryTransaction.show_name == show.show_name,
        models.InventoryTransaction.transaction_type == "sale"
    ).count()

    total_sales = Decimal(str(sales_result))
    total_expenses = Decimal(str(expenses_result))
    if show.table_cost:
        total_expenses += show.table_cost

    return ShowSummaryResponse(
        show=show,
        total_sales=total_sales,
        total_expenses=total_expenses,
        net_profit=total_sales - total_expenses,
        transaction_count=transaction_count
    )


@router.put("/{show_id}", response_model=ShowResponse)
def update_show(
    show_id: str,
    updates: ShowUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Update a show."""
    show = db.query(models.Show).filter(
        models.Show.show_id == show_id,
        models.Show.user_id == current_user.user_id
    ).first()

    if not show:
        raise HTTPException(status_code=404, detail="Show not found")

    for field, value in updates.model_dump(exclude_unset=True).items():
        setattr(show, field, value)

    show.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(show)
    return show


@router.post("/{show_id}/close", response_model=ShowSummaryResponse)
def close_show(
    show_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Close a show — marks it inactive and returns final P&L."""
    show = db.query(models.Show).filter(
        models.Show.show_id == show_id,
        models.Show.user_id == current_user.user_id
    ).first()

    if not show:
        raise HTTPException(status_code=404, detail="Show not found")
    if not show.is_active:
        raise HTTPException(status_code=400, detail="Show is already closed")

    show.is_active = False
    show.updated_at = datetime.utcnow()
    db.commit()

    # Return final summary via get_show
    return get_show(show_id, db, current_user)
