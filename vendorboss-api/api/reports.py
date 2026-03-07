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

# ── Helper: get card name + game for a product_id ────────────────────────────

def _card_display_name(product_id: str, db: Session):
    """Returns (card_name, game) for a product, checking tcg then sports tables."""
    tcg = db.query(models.TcgDetail).filter(models.TcgDetail.product_id == product_id).first()
    if tcg:
        game = "TCG"
        if tcg.category_id:
            cat = db.query(models.Category).filter(models.Category.category_id == tcg.category_id).first()
            game = cat.category_name if cat else "TCG"
        set_name = None
        if tcg.set_id:
            s = db.query(models.Set).filter(models.Set.set_id == tcg.set_id).first()
            set_name = s.set_name if s else None
        return tcg.card_name or "Unknown", game, set_name

    card = db.query(models.CardDetail).filter(models.CardDetail.product_id == product_id).first()
    if card:
        cat_name = "Sports"
        if card.category_id:
            cat = db.query(models.Category).filter(models.Category.category_id == card.category_id).first()
            cat_name = cat.category_name if cat else "Sports"
        set_name = None
        if card.set_id:
            s = db.query(models.Set).filter(models.Set.set_id == card.set_id).first()
            set_name = s.set_name if s else None
        return card.player or "Unknown", cat_name, set_name

    return "Unknown", "Other", None

# ── 3. Top Performers ─────────────────────────────────────────────────────────

class TopPerformerItem(BaseModel):
    inventory_id: str
    product_id: str
    card_name: str
    game: str
    set_name: Optional[str]
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
    """Top performing inventory items by profit margin, enriched with card names."""
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
        card_name, game, set_name = _card_display_name(r.product_id, db)

        items.append(TopPerformerItem(
            inventory_id=r.inventory_id,
            product_id=r.product_id,
            card_name=card_name,
            game=game,
            set_name=set_name,
            total_revenue=revenue,
            total_cost=cost,
            profit=profit,
            margin_percent=round(margin, 1) if margin is not None else None,
            units_sold=r.units_sold
        ))

    return TopPerformersResponse(items=items)

# ── 4. Inventory Health ───────────────────────────────────────────────────────

class InventoryHealthItem(BaseModel):
    inventory_id: str
    card_name: str
    game: str
    set_name: Optional[str]
    days_held: int
    capital_tied: Decimal
    asking_price: Optional[Decimal]
    market_price: Optional[Decimal]
    price_drift_pct: Optional[Decimal]  # positive = overpriced vs market

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
    items: List[InventoryHealthItem]

@router.get("/inventory-health", response_model=InventoryHealthResponse)
def inventory_health(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Inventory aging and health metrics with per-item detail."""
    today = date.today()

    inv_items = db.query(models.Inventory).filter(
        models.Inventory.user_id == current_user.user_id,
        models.Inventory.available_quantity > 0
    ).all()

    total_items = len(inv_items)
    total_cost = sum((i.purchase_price or Decimal("0")) * (i.available_quantity or 1) for i in inv_items)
    total_asking = sum((i.asking_price or Decimal("0")) * (i.available_quantity or 1) for i in inv_items)

    aged_30 = aged_60 = aged_90 = aged_180 = no_price = below_cost = 0
    detail_items = []

    for item in inv_items:
        days = 0
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

        # Price drift: how far is asking_price from market_price (%)
        price_drift = None
        if item.asking_price and item.current_market_price and item.current_market_price > 0:
            price_drift = round(
                (item.asking_price - item.current_market_price) / item.current_market_price * 100, 1
            )

        capital = (item.purchase_price or Decimal("0")) * (item.available_quantity or 1)
        card_name, game, set_name = _card_display_name(item.product_id, db)

        detail_items.append(InventoryHealthItem(
            inventory_id=item.inventory_id,
            card_name=card_name,
            game=game,
            set_name=set_name or "",
            days_held=days,
            capital_tied=capital,
            asking_price=item.asking_price,
            market_price=item.current_market_price,
            price_drift_pct=price_drift,
        ))

    # Sort by days_held descending (most aged first)
    detail_items.sort(key=lambda x: x.days_held, reverse=True)

    return InventoryHealthResponse(
        total_items=total_items,
        total_value_cost=total_cost,
        total_value_asking=total_asking,
        aged_30_plus=aged_30,
        aged_60_plus=aged_60,
        aged_90_plus=aged_90,
        aged_180_plus=aged_180,
        no_price=no_price,
        below_cost=below_cost,
        items=detail_items
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


# ── 6. Bulk Sales Effectiveness ───────────────────────────────────────────────

class BulkShowBreakdown(BaseModel):
    show_id: Optional[str]
    show_name: str
    bulk_revenue: Decimal
    single_revenue: Decimal
    total_revenue: Decimal
    bulk_count: int
    single_count: int
    bulk_pct: Decimal

class BulkSalesResponse(BaseModel):
    total_bulk_revenue: Decimal
    total_single_revenue: Decimal
    total_revenue: Decimal
    bulk_count: int
    single_count: int
    bulk_pct: Decimal
    avg_bulk_sale: Decimal
    by_show: List[BulkShowBreakdown]

@router.get("/bulk-sales", response_model=BulkSalesResponse)
def bulk_sales(
    year: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Bulk vs single sales breakdown. Bulk sales are identified by 'bulk' in notes."""
    from sqlalchemy import or_
    query = db.query(models.InventoryTransaction).filter(
        models.InventoryTransaction.user_id == current_user.user_id,
        models.InventoryTransaction.transaction_type == "sale"
    )
    if year:
        query = query.filter(
            extract('year', models.InventoryTransaction.transaction_date) == year
        )

    all_txns = query.all()

    def is_bulk(txn):
        return bool(txn.notes and 'bulk' in txn.notes.lower())

    total_bulk_rev = Decimal("0")
    total_single_rev = Decimal("0")
    bulk_count = 0
    single_count = 0

    # Group by show_id / show_name
    show_data: dict = {}

    for txn in all_txns:
        amount = Decimal(str(txn.total_amount or 0))
        show_key = txn.show_id or "__general__"
        show_name = txn.show_name or "General Sales"

        if show_key not in show_data:
            show_data[show_key] = {
                "show_id": txn.show_id,
                "show_name": show_name,
                "bulk_rev": Decimal("0"),
                "single_rev": Decimal("0"),
                "bulk_count": 0,
                "single_count": 0,
            }

        if is_bulk(txn):
            total_bulk_rev += amount
            bulk_count += 1
            show_data[show_key]["bulk_rev"] += amount
            show_data[show_key]["bulk_count"] += 1
        else:
            total_single_rev += amount
            single_count += 1
            show_data[show_key]["single_rev"] += amount
            show_data[show_key]["single_count"] += 1

    total_rev = total_bulk_rev + total_single_rev
    bulk_pct = round((total_bulk_rev / total_rev * 100) if total_rev > 0 else Decimal("0"), 1)
    avg_bulk = round(total_bulk_rev / bulk_count if bulk_count > 0 else Decimal("0"), 2)

    by_show = []
    for sd in show_data.values():
        show_total = sd["bulk_rev"] + sd["single_rev"]
        spct = round((sd["bulk_rev"] / show_total * 100) if show_total > 0 else Decimal("0"), 1)
        by_show.append(BulkShowBreakdown(
            show_id=sd["show_id"],
            show_name=sd["show_name"],
            bulk_revenue=sd["bulk_rev"],
            single_revenue=sd["single_rev"],
            total_revenue=show_total,
            bulk_count=sd["bulk_count"],
            single_count=sd["single_count"],
            bulk_pct=spct,
        ))

    by_show.sort(key=lambda x: x.total_revenue, reverse=True)

    return BulkSalesResponse(
        total_bulk_revenue=total_bulk_rev,
        total_single_revenue=total_single_rev,
        total_revenue=total_rev,
        bulk_count=bulk_count,
        single_count=single_count,
        bulk_pct=bulk_pct,
        avg_bulk_sale=avg_bulk,
        by_show=by_show,
    )
