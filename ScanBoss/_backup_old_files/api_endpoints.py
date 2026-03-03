"""
API Endpoints for VendorBoss Learning System
Add these to your FastAPI/Flask application

These endpoints implement the fleet learning system
"""

from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime

# Import your database connection and learning engine
# from your_app import get_db, CardLearningEngine

router = APIRouter(prefix="/api/scan", tags=["Card Scanner Learning"])


# ============================================
# Request/Response Models
# ============================================

class FingerprintCheckRequest(BaseModel):
    fingerprint: str
    confidence_threshold: Optional[float] = 0.7


class CardDataModel(BaseModel):
    player_name: Optional[str]
    card_year: Optional[int]
    card_set: Optional[str]


class FingerprintSubmitRequest(BaseModel):
    fingerprint: str
    card_data: CardDataModel
    user_id: Optional[int] = None


# ============================================
# Endpoints
# ============================================

@router.post("/fingerprint/check")
async def check_fingerprint(request: FingerprintCheckRequest, db=Depends(get_db)):
    """
    Check if a fingerprint is known with sufficient confidence
    
    This is the primary lookup endpoint for ScanBoss apps
    """
    try:
        engine = CardLearningEngine(db)
        result = engine.check_fingerprint(
            request.fingerprint,
            request.confidence_threshold
        )
        
        return result
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/fingerprint/submit")
async def submit_fingerprint(request: FingerprintSubmitRequest, db=Depends(get_db)):
    """
    Submit a new card data for learning
    
    Records user's input and calculates consensus
    """
    try:
        engine = CardLearningEngine(db)
        
        card_data = request.card_data.dict()
        result = engine.submit_fingerprint(
            request.fingerprint,
            card_data,
            request.user_id
        )
        
        if result['success']:
            return {
                "success": True,
                "message": "Submission recorded successfully",
                "consensus": result['consensus']
            }
        else:
            raise HTTPException(status_code=400, detail=result['error'])
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/model/updates")
async def get_model_updates(
    version: str = "1.0",
    last_update: Optional[str] = None,
    db=Depends(get_db)
):
    """
    Get model updates for ScanBoss apps
    
    Returns list of high-confidence known cards
    """
    try:
        engine = CardLearningEngine(db)
        
        # Check if update is needed
        latest_version = engine._get_latest_version()
        
        if version == latest_version and last_update:
            # Already up to date
            return {
                "update_available": False,
                "version": version
            }
        
        # Generate update package
        update = engine.generate_model_update(limit=10000)
        
        return {
            "update_available": True,
            "version": update['version'],
            "known_cards": update['known_cards'],
            "total_count": update['total_count'],
            "timestamp": update['created_at']
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/stats")
async def get_learning_stats(db=Depends(get_db)):
    """
    Get system-wide learning statistics
    
    Useful for monitoring and dashboards
    """
    try:
        engine = CardLearningEngine(db)
        stats = engine.get_stats()
        
        return stats
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/activity/recent")
async def get_recent_activity(
    hours: int = 24,
    limit: int = 100,
    db=Depends(get_db)
):
    """
    Get recent learning activity
    
    Shows what cards have been scanned recently
    """
    try:
        engine = CardLearningEngine(db)
        activity = engine.get_recent_activity(hours, limit)
        
        return {
            "activity": activity,
            "count": len(activity)
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============================================
# Admin/Management Endpoints
# ============================================

@router.post("/admin/model/generate")
async def generate_model(version: Optional[str] = None, db=Depends(get_db)):
    """
    Manually trigger model generation
    
    Admin only - generates new model version
    """
    try:
        engine = CardLearningEngine(db)
        update = engine.generate_model_update(version=version)
        
        return {
            "success": True,
            "version": update['version'],
            "card_count": update['total_count']
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/admin/fingerprint/{fingerprint}")
async def get_fingerprint_details(fingerprint: str, db=Depends(get_db)):
    """
    Get detailed information about a specific fingerprint
    
    Shows all submissions, consensus, and status
    """
    try:
        # Query database for this fingerprint
        query = """
            SELECT * FROM card_fingerprints
            WHERE fingerprint = %s
        """
        fp_data = db.execute(query, (fingerprint,)).fetchone()
        
        if not fp_data:
            raise HTTPException(status_code=404, detail="Fingerprint not found")
        
        # Get all submissions
        submissions_query = """
            SELECT 
                submitted_player_name,
                submitted_card_year,
                submitted_card_set,
                created_at,
                user_id
            FROM fingerprint_submissions
            WHERE fingerprint = %s
            ORDER BY created_at DESC
        """
        submissions = db.execute(submissions_query, (fingerprint,)).fetchall()
        
        return {
            "fingerprint": fp_data,
            "submissions": [dict(s) for s in submissions]
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============================================
# Flask Version (Alternative)
# ============================================

"""
# If you're using Flask instead of FastAPI:

from flask import Blueprint, request, jsonify

scanner_bp = Blueprint('scanner', __name__, url_prefix='/api/scan')

@scanner_bp.route('/fingerprint/check', methods=['POST'])
def check_fingerprint():
    data = request.get_json()
    fingerprint = data.get('fingerprint')
    threshold = data.get('confidence_threshold', 0.7)
    
    engine = CardLearningEngine(get_db())
    result = engine.check_fingerprint(fingerprint, threshold)
    
    return jsonify(result)

@scanner_bp.route('/fingerprint/submit', methods=['POST'])
def submit_fingerprint():
    data = request.get_json()
    
    engine = CardLearningEngine(get_db())
    result = engine.submit_fingerprint(
        data['fingerprint'],
        data['card_data'],
        data.get('user_id')
    )
    
    return jsonify(result)

# ... etc for other endpoints
"""
