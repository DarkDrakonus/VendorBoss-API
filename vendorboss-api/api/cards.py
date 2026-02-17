from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from database import get_db
import models

router = APIRouter(prefix="/cards", tags=["cards"])


@router.get("/by-code/{set_code}")
def get_card_by_code(
    set_code: str,
    foil: bool = Query(False, description="Filter for foil variants"),
    variant: Optional[str] = Query(None, description="Variant type: normal, full_art"),
    db: Session = Depends(get_db)
):
    """
    Get card by set code (OCR result)
    
    Examples:
    - /api/cards/by-code/24-073H
    - /api/cards/by-code/24-073H?foil=true
    - /api/cards/by-code/24-073H?variant=full_art&foil=true
    """
    
    # Query tcg_details by set_code
    query = db.query(models.TcgDetail).filter(
        models.TcgDetail.set_code == set_code
    )
    
    # Apply foil filter if specified
    if foil is not None:
        query = query.filter(models.TcgDetail.is_foil == foil)
    
    # Apply variant filter if specified
    if variant:
        query = query.filter(models.TcgDetail.variant_type == variant)
    
    tcg_cards = query.all()
    
    if not tcg_cards:
        raise HTTPException(
            status_code=404, 
            detail=f"No cards found with set code: {set_code}"
        )
    
    # Build response for each variant
    results = []
    for tcg in tcg_cards:
        product = db.query(models.Product).filter(
            models.Product.product_id == tcg.product_id
        ).first()
        
        if not product:
            continue
        
        # Get set info
        set_info = db.query(models.Set).filter(
            models.Set.set_id == tcg.set_id
        ).first() if tcg.set_id else None
        
        results.append({
            "product_id": product.product_id,
            "card_name": tcg.card_name,
            "set_code": tcg.set_code,
            "set_number": tcg.set_number,
            "card_number": tcg.card_number,
            "rarity_code": tcg.rarity_code,
            "variant_type": tcg.variant_type or "normal",
            "is_foil": tcg.is_foil or False,
            "element": tcg.element,
            "cost": tcg.cost,
            "power": tcg.power,
            "card_type": tcg.card_type,
            "job": tcg.job,
            "category": tcg.category,
            "abilities": tcg.abilities,
            "image_url": tcg.image_url,
            "set_name": set_info.set_name if set_info else None
        })
    
    return results


@router.post("/bulk-import")
def bulk_import_cards(
    cards: List[dict],
    db: Session = Depends(get_db)
):
    """
    Bulk import cards with fingerprints
    Used by CardHarvester
    
    Requires: X-API-Key header (TODO: add auth)
    """
    imported = 0
    errors = []
    
    for card_data in cards:
        try:
            # Create product
            product = models.Product(
                product_type_id="pt_card",  # Assuming 1 = Card
                barcode=card_data.get("barcode"),
                sku=card_data.get("sku")
            )
            db.add(product)
            db.flush()
            
            # Create TCG details
            tcg = models.TcgDetail(
                product_id=product.product_id,
                card_name=card_data["card_name"],
                set_code=card_data.get("set_code"),
                card_number=card_data.get("card_number"),
                rarity=card_data.get("rarity_code"),
                variant_type=card_data.get("variant_type", "normal"),
                is_foil=card_data.get("is_foil", False),
                element=card_data.get("element"),
                cost=card_data.get("cost"),
                power=card_data.get("power"),
                card_type=card_data.get("card_type"),
                job=card_data.get("job"),
                category=card_data.get("category"),
                text=card_data.get("abilities"),
                image_url=card_data.get("image_url")
            )
            db.add(tcg)
            
            # Create fingerprint if provided
            if "fingerprint" in card_data:
                fp_data = card_data["fingerprint"]
                fingerprint = models.CardFingerprint(
                    product_id=product.product_id,
                    fingerprint_hash=fp_data["composite_hash"],
                    border=fp_data["border"],
                    name_region=fp_data["name_region"],
                    color_zones=fp_data["color_zones"],
                    texture=fp_data["texture"],
                    layout=fp_data["layout"],
                    quadrant_0_0=fp_data["quadrant_0_0"],
                    quadrant_0_1=fp_data["quadrant_0_1"],
                    quadrant_0_2=fp_data["quadrant_0_2"],
                    quadrant_1_0=fp_data["quadrant_1_0"],
                    quadrant_1_1=fp_data["quadrant_1_1"],
                    quadrant_1_2=fp_data["quadrant_1_2"],
                    quadrant_2_0=fp_data["quadrant_2_0"],
                    quadrant_2_1=fp_data["quadrant_2_1"],
                    quadrant_2_2=fp_data["quadrant_2_2"],
                    verified=True,
                    auto_generated=True,
                    confidence_score=1.0
                )
                db.add(fingerprint)
            
            db.commit()
            imported += 1
            
        except Exception as e:
            db.rollback()
            errors.append({
                "card": card_data.get("card_name", "Unknown"),
                "error": str(e)
            })
    
    return {
        "success": True,
        "imported": imported,
        "total": len(cards),
        "errors": errors
    }
