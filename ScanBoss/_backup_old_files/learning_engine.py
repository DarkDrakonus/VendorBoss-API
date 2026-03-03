"""
Learning Engine for VendorBoss API
This module handles the fleet learning logic for ScanBoss
Place this file in your VendorBoss API project
"""

from typing import Dict, List, Optional, Tuple
from collections import Counter
from datetime import datetime, timedelta
import json


class CardLearningEngine:
    """
    The brain of the ScanBoss learning system
    Processes submissions and builds consensus
    """
    
    def __init__(self, db_connection):
        """
        Args:
            db_connection: Database connection object (psycopg2, SQLAlchemy, etc.)
        """
        self.db = db_connection
        
        # Learning parameters (can be tuned)
        self.min_submissions_for_confirmation = 3
        self.min_agreement_rate = 0.80  # 80% must agree
        self.confidence_threshold = 0.70  # 70% = "known"
        
    # ============================================
    # Core Learning Functions
    # ============================================
    
    def check_fingerprint(self, fingerprint: str, confidence_threshold: Optional[float] = None) -> Dict:
        """
        Check if a fingerprint is known with sufficient confidence
        
        Returns:
            {
                "known": True,
                "confidence": 0.95,
                "card_data": {...},
                "times_scanned": 47
            }
        """
        threshold = confidence_threshold or self.confidence_threshold
        
        # Query database for this fingerprint
        query = """
            SELECT 
                consensus_player_name,
                consensus_card_year,
                consensus_card_set,
                confidence_score,
                total_submissions,
                status
            FROM card_fingerprints
            WHERE fingerprint = %s
              AND confidence_score >= %s
              AND status = 'confirmed'
        """
        
        result = self.db.execute(query, (fingerprint, threshold)).fetchone()
        
        if result:
            return {
                "known": True,
                "confidence": float(result['confidence_score']),
                "card_data": {
                    "player_name": result['consensus_player_name'],
                    "card_year": result['consensus_card_year'],
                    "card_set": result['consensus_card_set'],
                    "times_scanned": result['total_submissions']
                }
            }
        else:
            return {
                "known": False,
                "confidence": 0.0,
                "card_data": None
            }
    
    def submit_fingerprint(self, fingerprint: str, card_data: Dict, user_id: Optional[int] = None) -> Dict:
        """
        Process a new card submission and update learning
        
        Args:
            fingerprint: Card fingerprint hash
            card_data: {
                "player_name": "Michael Jordan",
                "card_year": 1997,
                "card_set": "Upper Deck"
            }
            user_id: Optional user ID
            
        Returns:
            {
                "success": True,
                "message": "Submission recorded",
                "consensus": {...}
            }
        """
        try:
            # 1. Ensure fingerprint exists in card_fingerprints
            self._ensure_fingerprint_exists(fingerprint)
            
            # 2. Record the submission
            self._record_submission(fingerprint, card_data, user_id)
            
            # 3. Calculate new consensus
            consensus = self._calculate_consensus(fingerprint)
            
            # 4. Update fingerprint record
            self._update_fingerprint(fingerprint, consensus)
            
            # 5. Update user contributions (if user_id provided)
            if user_id:
                self._update_user_contributions(user_id, fingerprint, card_data, consensus)
            
            return {
                "success": True,
                "message": "Submission recorded successfully",
                "consensus": {
                    "total_submissions": consensus['total_count'],
                    "confidence": float(consensus['confidence']),
                    "status": consensus['status'],
                    "card_data": {
                        "player_name": consensus['player_name'],
                        "card_year": consensus['card_year'],
                        "card_set": consensus['card_set']
                    }
                }
            }
            
        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }
    
    def _ensure_fingerprint_exists(self, fingerprint: str):
        """Create fingerprint record if it doesn't exist"""
        query = """
            INSERT INTO card_fingerprints (fingerprint, status)
            VALUES (%s, 'learning')
            ON CONFLICT (fingerprint) DO NOTHING
        """
        self.db.execute(query, (fingerprint,))
        self.db.commit()
    
    def _record_submission(self, fingerprint: str, card_data: Dict, user_id: Optional[int]):
        """Record an individual submission"""
        query = """
            INSERT INTO fingerprint_submissions (
                fingerprint,
                user_id,
                submitted_player_name,
                submitted_card_year,
                submitted_card_set
            ) VALUES (%s, %s, %s, %s, %s)
        """
        
        self.db.execute(query, (
            fingerprint,
            user_id,
            card_data.get('player_name'),
            card_data.get('card_year'),
            card_data.get('card_set')
        ))
        self.db.commit()
    
    def _calculate_consensus(self, fingerprint: str) -> Dict:
        """
        Calculate consensus from all submissions for a fingerprint
        Uses majority voting for each field
        """
        # Get all submissions
        query = """
            SELECT 
                submitted_player_name,
                submitted_card_year,
                submitted_card_set
            FROM fingerprint_submissions
            WHERE fingerprint = %s
        """
        
        submissions = self.db.execute(query, (fingerprint,)).fetchall()
        
        if not submissions:
            return {
                'player_name': None,
                'card_year': None,
                'card_set': None,
                'total_count': 0,
                'agreement_rate': 0.0,
                'confidence': 0.0,
                'status': 'learning'
            }
        
        # Count votes for each field
        player_votes = Counter([s['submitted_player_name'] for s in submissions if s['submitted_player_name']])
        year_votes = Counter([s['submitted_card_year'] for s in submissions if s['submitted_card_year']])
        set_votes = Counter([s['submitted_card_set'] for s in submissions if s['submitted_card_set']])
        
        total_submissions = len(submissions)
        
        # Get most common values
        consensus_player = player_votes.most_common(1)[0][0] if player_votes else None
        consensus_year = year_votes.most_common(1)[0][0] if year_votes else None
        consensus_set = set_votes.most_common(1)[0][0] if set_votes else None
        
        # Calculate agreement rate (% that agree with consensus)
        player_agreement = player_votes.most_common(1)[0][1] / total_submissions if player_votes else 0
        
        # Calculate confidence based on submissions and agreement
        confidence = self._calculate_confidence(total_submissions, player_agreement)
        
        # Determine status
        status = self._determine_status(total_submissions, player_agreement, confidence)
        
        return {
            'player_name': consensus_player,
            'card_year': consensus_year,
            'card_set': consensus_set,
            'total_count': total_submissions,
            'agreement_rate': player_agreement,
            'confidence': confidence,
            'status': status
        }
    
    def _calculate_confidence(self, total_submissions: int, agreement_rate: float) -> float:
        """
        Calculate confidence score
        Confidence increases with both number of submissions and agreement rate
        """
        # Base confidence from submissions (max at 10 submissions)
        submission_confidence = min(1.0, total_submissions / 10.0)
        
        # Weight: 60% agreement rate, 40% submission count
        confidence = (agreement_rate * 0.6) + (submission_confidence * 0.4)
        
        return round(confidence, 3)
    
    def _determine_status(self, total_submissions: int, agreement_rate: float, confidence: float) -> str:
        """Determine the status of a fingerprint"""
        if total_submissions < self.min_submissions_for_confirmation:
            return 'learning'
        
        if agreement_rate >= self.min_agreement_rate and confidence >= self.confidence_threshold:
            return 'confirmed'
        
        if agreement_rate < 0.5:  # Less than 50% agree
            return 'disputed'
        
        return 'learning'
    
    def _update_fingerprint(self, fingerprint: str, consensus: Dict):
        """Update fingerprint record with new consensus"""
        confirmed_at = datetime.now() if consensus['status'] == 'confirmed' else None
        
        query = """
            UPDATE card_fingerprints
            SET 
                consensus_player_name = %s,
                consensus_card_year = %s,
                consensus_card_set = %s,
                total_submissions = %s,
                agreement_rate = %s,
                confidence_score = %s,
                status = %s,
                confirmed_at = COALESCE(confirmed_at, %s),
                last_seen = CURRENT_TIMESTAMP
            WHERE fingerprint = %s
        """
        
        self.db.execute(query, (
            consensus['player_name'],
            consensus['card_year'],
            consensus['card_set'],
            consensus['total_count'],
            consensus['agreement_rate'],
            consensus['confidence'],
            consensus['status'],
            confirmed_at,
            fingerprint
        ))
        self.db.commit()
    
    def _update_user_contributions(self, user_id: int, fingerprint: str, card_data: Dict, consensus: Dict):
        """Update user contribution stats"""
        # Check if submission matches consensus
        matches_consensus = (
            card_data.get('player_name') == consensus['player_name'] and
            card_data.get('card_year') == consensus['card_year'] and
            card_data.get('card_set') == consensus['card_set']
        )
        
        query = """
            INSERT INTO user_contributions (
                user_id,
                total_submissions,
                accurate_submissions,
                last_contribution
            ) VALUES (%s, 1, %s, CURRENT_TIMESTAMP)
            ON CONFLICT (user_id) DO UPDATE SET
                total_submissions = user_contributions.total_submissions + 1,
                accurate_submissions = user_contributions.accurate_submissions + %s,
                last_contribution = CURRENT_TIMESTAMP
        """
        
        accurate = 1 if matches_consensus else 0
        self.db.execute(query, (user_id, accurate, accurate))
        self.db.commit()
    
    # ============================================
    # Model Generation
    # ============================================
    
    def generate_model_update(self, version: Optional[str] = None, limit: int = 10000) -> Dict:
        """
        Generate a model update package for ScanBoss apps
        Contains high-confidence known cards
        
        Args:
            version: Version string (auto-generated if None)
            limit: Maximum number of cards to include
            
        Returns:
            {
                "version": "1.2",
                "known_cards": [...],
                "total_count": 1500,
                "created_at": "2024-01-01T00:00:00"
            }
        """
        # Auto-generate version if not provided
        if not version:
            latest_version = self._get_latest_version()
            version = self._increment_version(latest_version)
        
        # Get confirmed cards with high confidence
        query = """
            SELECT 
                fingerprint,
                consensus_player_name as player_name,
                consensus_card_year as card_year,
                consensus_card_set as card_set,
                confidence_score as confidence,
                total_submissions
            FROM card_fingerprints
            WHERE status = 'confirmed'
              AND confidence_score >= %s
            ORDER BY total_submissions DESC, confidence_score DESC
            LIMIT %s
        """
        
        known_cards = self.db.execute(
            query, 
            (self.confidence_threshold, limit)
        ).fetchall()
        
        # Convert to list of dicts
        cards_list = [
            {
                'fingerprint': card['fingerprint'],
                'player_name': card['player_name'],
                'card_year': card['card_year'],
                'card_set': card['card_set'],
                'confidence': float(card['confidence'])
            }
            for card in known_cards
        ]
        
        # Save version to database
        self._save_model_version(version, len(cards_list))
        
        return {
            "version": version,
            "known_cards": cards_list,
            "total_count": len(cards_list),
            "created_at": datetime.now().isoformat()
        }
    
    def _get_latest_version(self) -> str:
        """Get the latest model version"""
        query = "SELECT version FROM model_versions ORDER BY created_at DESC LIMIT 1"
        result = self.db.execute(query).fetchone()
        return result['version'] if result else "1.0"
    
    def _increment_version(self, version: str) -> str:
        """Increment version number (e.g., 1.0 -> 1.1)"""
        try:
            major, minor = version.split('.')
            return f"{major}.{int(minor) + 1}"
        except:
            return "1.0"
    
    def _save_model_version(self, version: str, card_count: int):
        """Save model version to database"""
        query = """
            INSERT INTO model_versions (version, known_cards_count)
            VALUES (%s, %s)
            ON CONFLICT (version) DO UPDATE SET
                known_cards_count = %s
        """
        self.db.execute(query, (version, card_count, card_count))
        self.db.commit()
    
    # ============================================
    # Statistics & Monitoring
    # ============================================
    
    def get_stats(self) -> Dict:
        """Get system-wide statistics"""
        query = "SELECT * FROM learning_stats"
        stats = self.db.execute(query).fetchone()
        
        return {
            "total_fingerprints": stats['total_fingerprints'],
            "confirmed_cards": stats['confirmed_cards'],
            "learning_cards": stats['learning_cards'],
            "disputed_cards": stats['disputed_cards'],
            "total_submissions": stats['total_submissions'],
            "average_confidence": float(stats['average_confidence']) if stats['average_confidence'] else 0.0,
            "last_activity": stats['last_activity'].isoformat() if stats['last_activity'] else None
        }
    
    def get_recent_activity(self, hours: int = 24, limit: int = 100) -> List[Dict]:
        """Get recent learning activity"""
        query = """
            SELECT 
                f.fingerprint,
                f.consensus_player_name,
                f.total_submissions,
                f.confidence_score,
                f.status,
                f.last_seen
            FROM card_fingerprints f
            WHERE f.last_seen >= NOW() - INTERVAL '%s hours'
            ORDER BY f.last_seen DESC
            LIMIT %s
        """
        
        results = self.db.execute(query, (hours, limit)).fetchall()
        
        return [
            {
                'fingerprint': r['fingerprint'][:16] + '...',
                'player': r['consensus_player_name'],
                'submissions': r['total_submissions'],
                'confidence': float(r['confidence_score']),
                'status': r['status'],
                'last_seen': r['last_seen'].isoformat()
            }
            for r in results
        ]
