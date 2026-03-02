"""
Reports endpoints
Aggregated business intelligence for vendors
Matches the 7 report modules in the Flutter app
"""
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import func, case, and_, extract
from typing import Optional, List
from datetime import date, datetime
from decimal import Decimal
from pydantic import BaseModel

import models
from database import get_db
from auth import get_current_user

router = APIRouter(prefix="/reports", tags=["Reports"])

# ── Shared schemas ────────────────────────────────────────────────────────────

class MonthlyDataPoint(BaseModel):
    month: str
    revenue: Decimal
    expenses: Decimal
    net_profit: Decimal
    transaction_count: int

# ── 1. Show ROI ───────────────────────────────────────────────────────────────

class ShowROIItem(BaseModel):
    show_id: str
    show_name: str
    show_date: date
    location: Optional[str]
    total_sales: Decimal
    total_expenses: Decimal
    table_cost: Decimal
    net_profit: Decimal
    roi_percent: Optional[Decimal]
    transaction_count: int

class ShowROIResponse(BaseModel):
    shows: List[ShowROIItem]
    total_sales: Decimal
    total_expenses: Decimal
    total_net_profit: Decimal

@router.get("/show-roi", response_model=ShowROIResponse)
def show_roi(
    year: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Per-show ROI breakdown."""
    query = db.query(models.Show).filter(
        models.Show.user_id == current_user.user_id
    )
    if year:
        query = query.filter(extract('year', models.Show.show_date) == year)

    shows = query.order_by(models.Show.show_date.desc()).all()
    result = []

    for show in shows:
        sales = db.query(
            func.coalesce(func.sum(models.InventoryTransaction.total_amount), 0)
        ).filter(
            models.InventoryTransaction.user_id == current_user.user_id,
            models.InventoryTransaction.show_name == show.show_name,
            models.InventoryTransaction.transaction_type == "sale"
        ).scalar()

        expenses = db.query(
            func.coalesce(func.sum(models.Expense.amount), 0)
        ).filter(
            models.Expense.user_id == current_user.user_id,
            models.Expense.show_id == show.show_id
        ).scalar()

        count = db.query(func.count(models.InventoryTransaction.transaction_id)).filter(
            models.InventoryTransaction.user_id == current_user.user_id,
            models.InventoryTransaction.show_name == show.show_name,
            models.InventoryTransaction.transaction_type == "sale"
        ).scalar()

        total_sales = Decimal(str(sales))
        table_cost = show.table_cost or Decimal("0")
        total_expenses = Decimal(str(expenses)) + table_cost
        net_profit = total_sales - total_expenses
        roi = (net_profit / total_expenses * 100) if total_expenses > 0 else None

        result.append(ShowROIItem(
            show_id=show.show_id,
            show_name=show.show_name,
            show_date=show.show_date,
            location=show.location,
            total_sales=total_sales,
            total_expenses=total_expenses,
            table_cost=table_cost,
            net_profit=net_profit,
            roi_percent=round(roi, 1) if roi is not None else None,
            transaction_count=count
        ))

    total_sales = sum(s.total_sales for s in result)
    total_expenses = sum(s.total_expenses for s in result)

    return ShowROIResponse(
        shows=result,
        total_sales=total_sales,
        total_expenses=total_expenses,
        total_net_profit=total_sales - total_expenses
    )

# ── 2. Financial Summary ──────────────────────────────────────────────────────

class FinancialSummaryResponse(BaseModel):
    year: int
    total_revenue: Decimal
    total_cogs: Decimal
    total_expenses: Decimal
    gross_profit: Decimal
    net_profit: Decimal
    total_transactions: int
    monthly: List[MonthlyDataPoint]

@router.get("/financial-summary", response_model=FinancialSummaryResponse)
def financial_summary(
    year: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """YTD financial overview with monthly breakdown."""
    target_year = year or datetime.utcnow().year

    # Total revenue
    revenue = db.query(
        func.coalesce(func.sum(models.InventoryTransaction.total_amount), 0)
    ).filter(
        models.InventoryTransaction.user_id == current_user.user_id,
        models.InventoryTransaction.transaction_type == "sale",
        extract('year', models.InventoryTransaction.transaction_date) == target_year
    ).scalar()

    # Total expenses
    expenses = db.query(
        func.coalesce(func.sum(models.Expense.amount), 0)
    ).filter(
        models.Expense.user_id == current_user.user_id,
        extract('year', models.Expense.expense_date) == target_year
    ).scalar()

    # Table costs from shows
    table_costs = db.query(
        func.coalesce(func.sum(models.Show.table_cost), 0)
    ).filter(
        models.Show.user_id == current_user.user_id,
        extract('year', models.Show.show_date) == target_year
    ).scalar()

    # COGS — sum of purchase prices for sold items
    cogs = db.query(
        func.coalesce(
            func.sum(models.Inventory.purchase_price * models.InventoryTransaction.quantity), 0
        )
    ).join(
        models.Inventory,
        models.InventoryTransaction.inventory_id == models.Inventory.inventory_id
    ).filter(
        models.InventoryTransaction.user_id == current_user.user_id,
        models.InventoryTransaction.transaction_type == "sale",
        extract('year', models.InventoryTransaction.transaction_date) == target_year
    ).scalar()

    total_revenue = Decimal(str(revenue))
    total_expenses = Decimal(str(expenses)) + Decimal(str(table_costs))
    total_cogs = Decimal(str(cogs))
    gross_profit = total_revenue - total_cogs
    net_profit = gross_profit - total_expenses

    # Monthly breakdown
    monthly = []
    for month in range(1, 13):
        m_revenue = db.query(
            func.coalesce(func.sum(models.InventoryTransaction.total_amount), 0)
        ).filter(
            models.InventoryTransaction.user_id == current_user.user_id,
            models.InventoryTransaction.transaction_type == "sale",
            extract('year', models.InventoryTransaction.transaction_date) == target_year,
            extract('month', models.InventoryTransaction.transaction_date) == month
        ).scalar()

        m_expenses = db.query(
            func.coalesce(func.sum(models.Expense.amount), 0)
        ).filter(
            models.Expense.user_id == current_user.user_id,
            extract('year', models.Expense.expense_date) == target_year,
            extract('month', models.Expense.expense_date) == month
        ).scalar()

        m_count = db.query(func.count(models.InventoryTransaction.transaction_id)).filter(
            models.InventoryTransaction.user_id == current_user.user_id,
            models.InventoryTransaction.transaction_type == "sale",
            extract('year', models.InventoryTransaction.transaction_date) == target_year,
            extract('month', models.InventoryTransaction.transaction_date) == month
        ).scalar()

        m_rev = Decimal(str(m_revenue))
        m_exp = Decimal(str(m_expenses))

        monthly.append(MonthlyDataPoint(
            month=datetime(target_year, month, 1).strftime("%b"),
            revenue=m_rev,
            expenses=m_exp,
            net_profit=m_rev - m_exp,
            transaction_count=m_count
        ))

    total_transactions = db.query(
        func.count(models.InventoryTransaction.transaction_id)
    ).filter(
        models.InventoryTransaction.user_id == current_user.user_id,
        models.InventoryTransaction.transaction_type == "sale",
        extract('year', models.InventoryTransaction.transaction_date) == target_year
    ).scalar()

    return FinancialSummaryResponse(
        year=target_year,
        total_revenue=total_revenue,
        total_cogs=total_cogs,
        total_expenses=total_expenses,
        gross_profit=gross_profit,
        net_profit=net_profit,
        total_transactions=total_transactions,
        monthly=monthly
    )

# ── 3. Top Performers ─────────────────────────────────────────────────────────

class TopPerformerItem(BaseModel):
    inventory_id: str
    product_id: str
    total_revenue: Decimal
    total_cost: Decimal
    profit: Decimal
    margin_percent: Optional[Decimal]
    units_sold: int

class TopPerformersResponse(BaseModel):
    items: List[TopPerformerItem]

@router.get("/top-performers", response_model=TopPerformersResponse)
def top_performers(
    limit: int = Query(20, ge=1, le=100),
    year: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Top performing inventory items by profit margin."""
    query = db.query(
        models.InventoryTransaction.inventory_id,
        func.sum(models.InventoryTransaction.total_amount).label("total_revenue"),
        func.sum(models.InventoryTransaction.quantity).label("units_sold"),
        models.Inventory.purchase_price,
        models.Inventory.product_id
    ).join(
        models.Inventory,
        models.InventoryTransaction.inventory_id == models.Inventory.inventory_id
    ).filter(
        models.InventoryTransaction.user_id == current_user.user_id,
        models.InventoryTransaction.transaction_type == "sale"
    )

    if year:
        query = query.filter(
            extract('year', models.InventoryTransaction.transaction_date) == year
        )

    results = query.group_by(
        models.InventoryTransaction.inventory_id,
        models.Inventory.purchase_price,
        models.Inventory.product_id
    ).order_by(func.sum(models.InventoryTransaction.total_amount).desc()).limit(limit).all()

    items = []
    for r in results:
        revenue = Decimal(str(r.total_revenue or 0))
        cost = Decimal(str(r.purchase_price or 0)) * r.units_sold
        profit = revenue - cost
        margin = (profit / revenue * 100) if revenue > 0 else None

        items.append(TopPerformerItem(
            inventory_id=r.inventory_id,
            product_id=r.product_id,
            total_revenue=revenue,
            total_cost=cost,
            profit=profit,
            margin_percent=round(margin, 1) if margin is not None else None,
            units_sold=r.units_sold
        ))

    return TopPerformersResponse(items=items)

# ── 4. Inventory Health ───────────────────────────────────────────────────────

class InventoryHealthResponse(BaseModel):
    total_items: int
    total_value_cost: Decimal
    total_value_asking: Decimal
    aged_30_plus: int
    aged_60_plus: int
    aged_90_plus: int
    aged_180_plus: int
    no_price: int
    below_cost: int

@router.get("/inventory-health", response_model=InventoryHealthResponse)
def inventory_health(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Inventory aging and health metrics."""
    today = date.today()

    items = db.query(models.Inventory).filter(
        models.Inventory.user_id == current_user.user_id,
        models.Inventory.available_quantity > 0
    ).all()

    total_items = len(items)
    total_cost = sum((i.purchase_price or Decimal("0")) * (i.available_quantity or 1) for i in items)
    total_asking = sum((i.asking_price or Decimal("0")) * (i.available_quantity or 1) for i in items)

    aged_30 = aged_60 = aged_90 = aged_180 = no_price = below_cost = 0

    for item in items:
        if item.acquired_date:
            days = (today - item.acquired_date).days
            if days >= 180: aged_180 += 1
            elif days >= 90: aged_90 += 1
            elif days >= 60: aged_60 += 1
            elif days >= 30: aged_30 += 1

        if not item.asking_price:
            no_price += 1
        elif item.purchase_price and item.asking_price < item.purchase_price:
            below_cost += 1

    return InventoryHealthResponse(
        total_items=total_items,
        total_value_cost=total_cost,
        total_value_asking=total_asking,
        aged_30_plus=aged_30,
        aged_60_plus=aged_60,
        aged_90_plus=aged_90,
        aged_180_plus=aged_180,
        no_price=no_price,
        below_cost=below_cost
    )

# ── 5. Channel Performance ────────────────────────────────────────────────────

class ChannelDataPoint(BaseModel):
    channel: str
    total_revenue: Decimal
    transaction_count: int
    avg_sale: Decimal

class ChannelPerformanceResponse(BaseModel):
    channels: List[ChannelDataPoint]
    total_revenue: Decimal

@router.get("/channel-performance", response_model=ChannelPerformanceResponse)
def channel_performance(
    year: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Revenue breakdown by payment/sales channel."""
    query = db.query(
        func.coalesce(models.InventoryTransaction.payment_method, "untracked").label("channel"),
        func.sum(models.InventoryTransaction.total_amount).label("total_revenue"),
        func.count(models.InventoryTransaction.transaction_id).label("count")
    ).filter(
        models.InventoryTransaction.user_id == current_user.user_id,
        models.InventoryTransaction.transaction_type == "sale"
    )

    if year:
        query = query.filter(
            extract('year', models.InventoryTransaction.transaction_date) == year
        )

    results = query.group_by("channel").order_by(
        func.sum(models.InventoryTransaction.total_amount).desc()
    ).all()

    channels = []
    total = Decimal("0")

    for r in results:
        rev = Decimal(str(r.total_revenue or 0))
        avg = rev / r.count if r.count > 0 else Decimal("0")
        total += rev
        channels.append(ChannelDataPoint(
            channel=r.channel,
            total_revenue=rev,
            transaction_count=r.count,
            avg_sale=round(avg, 2)
        ))

    return ChannelPerformanceResponse(channels=channels, total_revenue=total)
