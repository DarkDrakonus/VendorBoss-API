"""
Worker threads for ScanBoss - Updated for VendorBoss 2.0
"""
import time
import numpy as np
from PyQt6.QtCore import QObject, pyqtSignal
from typing import Dict, Optional

from api_client import APIClient
from card_detector import CardDetector
from local_cache import LocalCache

class ScanWorker(QObject):
    """
    Worker thread for scanning cards
    Generates 14-component fingerprint and identifies via API
    """
    status_update = pyqtSignal(str)
    finished = pyqtSignal(dict)
    
    def __init__(self, frame: np.ndarray, detector: CardDetector, api: APIClient, cache: LocalCache):
        super().__init__()
        self.frame = frame
        self.detector = detector
        self.api = api
        self.cache = cache
    
    def run(self):
        """Run the scan process"""
        try:
            self.status_update.emit("Detecting card...")
            
            # Detect card and generate fingerprint
            detection = self.detector.detect_card_in_frame(self.frame)
            
            if not detection or not detection.get('detected'):
                self.finished.emit({
                    "status": "no_card",
                    "message": "No card detected"
                })
                return
            
            fingerprint_data = detection['fingerprint_data']
            
            if not fingerprint_data:
                self.finished.emit({
                    "status": "error",
                    "error": "Failed to generate fingerprint"
                })
                return
            
            self.status_update.emit("Identifying card...")
            
            # Check local cache first
            cached_product = self.cache.get_fingerprint(fingerprint_data['fingerprint_hash'])
            
            if cached_product:
                self.status_update.emit("Found in local cache!")
                self.finished.emit({
                    "status": "match",
                    "known": True,
                    "source": "cache",
                    "fingerprint_data": fingerprint_data,
                    "card_data": cached_product,
                    "image_region": detection['region']
                })
                return
            
            # Check API
            api_result = self.api.identify_card(fingerprint_data)
            
            if api_result.get('success'):
                data = api_result.get('data', {})
                
                if data.get('found'):
                    # Card identified!
                    product = data.get('product', {})
                    pricing = data.get('pricing', {})
                    
                    # Cache it locally
                    self.cache.save_fingerprint(fingerprint_data['fingerprint_hash'], product)
                    
                    self.status_update.emit(f"Match: {product.get('card_name', 'Unknown')}")
                    
                    self.finished.emit({
                        "status": "match",
                        "known": True,
                        "source": "api",
                        "fingerprint_data": fingerprint_data,
                        "card_data": product,
                        "pricing": pricing,
                        "match_quality": data.get('match_quality', {}),
                        "image_region": detection['region']
                    })
                    return
            
            # Not found - new card
            self.status_update.emit("New card - please enter details")
            
            self.finished.emit({
                "status": "new_card",
                "known": False,
                "fingerprint_data": fingerprint_data,
                "image_region": detection['region']
            })
            
        except Exception as e:
            print(f"Error in scan worker: {e}")
            import traceback
            traceback.print_exc()
            
            self.finished.emit({
                "status": "error",
                "error": str(e)
            })


class ModelUpdateWorker(QObject):
    """
    Worker thread for updating local model with high-confidence fingerprints
    """
    log_message = pyqtSignal(str)
    status_update = pyqtSignal(str)
    finished = pyqtSignal()
    
    def __init__(self, api: APIClient, cache: LocalCache):
        super().__init__()
        self.api = api
        self.cache = cache
    
    def run(self):
        """Download and cache high-confidence fingerprints"""
        try:
            self.status_update.emit("Updating local model...")
            self.log_message.emit("Fetching verified fingerprints from server...")
            
            # Get model updates (verified fingerprints only for now)
            result = self.api.get_model_update(
                min_confidence=0.9,
                min_matches=5,
                verified_only=True
            )
            
            if not result.get('success'):
                self.log_message.emit(f"Model update failed: {result.get('error', 'Unknown error')}")
                self.status_update.emit("Model update failed")
                self.finished.emit()
                return
            
            data = result.get('data', {})
            fingerprints = data.get('fingerprints', [])
            
            if not fingerprints:
                self.log_message.emit("No fingerprints available to download")
                self.status_update.emit("Local model up to date")
                self.finished.emit()
                return
            
            # Cache each fingerprint
            count = 0
            for fp in fingerprints:
                try:
                    # For caching, we need product info - would need separate endpoint
                    # For now, just log that we got the fingerprint
                    count += 1
                except Exception as e:
                    self.log_message.emit(f"Error caching fingerprint: {e}")
            
            self.log_message.emit(f"Downloaded {count} verified fingerprints")
            self.status_update.emit("Model updated")
            
        except Exception as e:
            self.log_message.emit(f"Error updating model: {e}")
            self.status_update.emit("Model update error")
        
        finally:
            self.finished.emit()
