import requests
import json
import logging
from typing import Dict, Any, Optional

logger = logging.getLogger(__name__)

class APIClient:
    """
    VendorBoss 2.0 API Client
    Compatible with new fingerprint endpoints and FFTCG data structure
    """
    
    def __init__(self, base_url: str = "http://localhost:8000", api_key: Optional[str] = None):
        self.base_url = base_url
        self.timeout = 10
        self.session = requests.Session()
        
        if api_key:
            self.session.headers.update({"X-API-Key": api_key})
        
        logger.info(f"APIClient initialized for {self.base_url}")

    def _request(self, method: str, endpoint: str, **kwargs) -> Dict:
        """Make HTTP request with error handling"""
        url = f"{self.base_url}{endpoint}"
        headers = self.session.headers.copy()
        
        if 'headers' in kwargs:
            headers.update(kwargs['headers'])
        kwargs['headers'] = headers

        try:
            response = self.session.request(method, url, timeout=self.timeout, **kwargs)
            response.raise_for_status()
            
            return {
                "success": True,
                "data": response.json() if response.content else None,
                "status_code": response.status_code
            }
            
        except requests.exceptions.HTTPError as e:
            error_detail = "Server error"
            try:
                error_data = e.response.json()
                error_detail = error_data.get('detail', str(e))
            except:
                error_detail = str(e)
                
            return {
                "success": False,
                "error": error_detail,
                "status_code": e.response.status_code if e.response else 500
            }
            
        except requests.exceptions.RequestException as e:
            return {
                "success": False,
                "error": f"Connection error: {str(e)}",
                "status_code": 0
            }

    # ========================================================================
    # FINGERPRINT ENDPOINTS (VendorBoss 2.0)
    # ========================================================================

    def identify_card(self, fingerprint_data: Dict) -> Dict:
        """
        Identify a card using 14-component fingerprint
        
        Args:
            fingerprint_data: {
                'fingerprint_hash': '64-char SHA-256',
                'components': {
                    'border': '16-char MD5',
                    'name_region': '16-char MD5',
                    ...14 components total
                }
            }
        
        Returns:
            {
                'success': bool,
                'data': {
                    'found': bool,
                    'product': {...},
                    'pricing': {...},
                    'match_quality': {...}
                }
            }
        """
        logger.info(f"Identifying card with fingerprint: {fingerprint_data['fingerprint_hash'][:16]}...")
        
        payload = {
            "fingerprint_hash": fingerprint_data['fingerprint_hash'],
            "components": fingerprint_data['components']
        }
        
        return self._request("POST", "/api/fingerprints/identify", json=payload)

    def submit_fingerprint(self, fingerprint_data: Dict, product_id: str, verified: bool = True) -> Dict:
        """
        Submit a learned fingerprint to the database (ScanBoss only)
        Requires X-API-Key header
        
        Args:
            fingerprint_data: Full fingerprint data
            product_id: Product ID this fingerprint belongs to
            verified: Whether this was manually verified by user
        """
        logger.info(f"Submitting fingerprint for product: {product_id}")
        
        payload = {
            "fingerprint_hash": fingerprint_data['fingerprint_hash'],
            "components": fingerprint_data['components'],
            "product_id": product_id,
            "raw_components": fingerprint_data.get('raw_components'),
            "verified": verified
        }
        
        return self._request("POST", "/api/fingerprints/submit", json=payload)

    def confirm_identification(self, fingerprint_hash: str, confirmed: bool, actual_product_id: Optional[str] = None) -> Dict:
        """
        User confirms or rejects an identification
        
        Args:
            fingerprint_hash: The fingerprint that was identified
            confirmed: True if correct, False if wrong
            actual_product_id: If wrong, what it actually is
        """
        logger.info(f"Confirming identification: {confirmed}")
        
        payload = {
            "fingerprint_hash": fingerprint_hash,
            "confirmed": confirmed,
            "actual_product_id": actual_product_id
        }
        
        return self._request("POST", "/api/fingerprints/confirm", json=payload)

    def get_model_update(self, min_confidence: float = 0.8, min_matches: int = 3, verified_only: bool = False) -> Dict:
        """
        Download high-confidence fingerprints for local model (ScanBoss only)
        Requires X-API-Key header
        """
        logger.info("Fetching model updates...")
        
        params = {
            "min_confidence": min_confidence,
            "min_matches": min_matches,
            "verified_only": verified_only
        }
        
        return self._request("GET", "/api/fingerprints/model", params=params)

    # ========================================================================
    # METADATA ENDPOINTS (FFTCG)
    # ========================================================================

    def get_sets(self) -> Dict:
        """Get all FFTCG sets"""
        logger.info("Fetching FFTCG sets...")
        return self._request("GET", "/api/sets")

    def get_elements(self) -> Dict:
        """Get all FFTCG elements"""
        logger.info("Fetching FFTCG elements...")
        return self._request("GET", "/api/elements")

    def get_rarities(self) -> Dict:
        """Get all FFTCG rarities"""
        logger.info("Fetching FFTCG rarities...")
        return self._request("GET", "/api/rarities")

    # ========================================================================
    # PRODUCT SUBMISSION (For new cards)
    # ========================================================================

    def submit_new_card(self, fingerprint_data: Dict, card_data: Dict, image_bytes: Optional[bytes] = None) -> Dict:
        """
        Submit a new card with fingerprint
        
        Args:
            fingerprint_data: Full 14-component fingerprint
            card_data: {
                'card_name': str,
                'set_id': str,
                'card_number': str,
                'element': str,
                'card_type': str,
                'rarity': str,
                'power': int (optional),
                'cost': int (optional),
                ...
            }
            image_bytes: Card image (JPEG)
        """
        logger.info(f"Submitting new card: {card_data.get('card_name', 'Unknown')}")
        
        endpoint = "/api/products"
        url = f"{self.base_url}{endpoint}"
        
        # Build multipart form data
        form_data = {
            'fingerprint_hash': (None, fingerprint_data['fingerprint_hash']),
            'fingerprint_components': (None, json.dumps(fingerprint_data['components'])),
            'card_data': (None, json.dumps(card_data)),
        }
        
        if fingerprint_data.get('raw_components'):
            form_data['raw_components'] = (None, json.dumps(fingerprint_data['raw_components']))
        
        if image_bytes:
            form_data['image'] = ('card_image.jpg', image_bytes, 'image/jpeg')

        # Remove Content-Type header (let requests set it for multipart)
        request_headers = self.session.headers.copy()
        if 'Content-Type' in request_headers:
            del request_headers['Content-Type']

        try:
            response = self.session.post(
                url,
                files=form_data,
                headers=request_headers,
                timeout=self.timeout
            )
            response.raise_for_status()
            
            return {
                "success": True,
                "data": response.json(),
                "status_code": response.status_code
            }
            
        except requests.exceptions.HTTPError as e:
            error_detail = "Server error"
            try:
                error_data = e.response.json()
                error_detail = error_data.get('detail', str(e))
            except:
                error_detail = str(e)
                
            return {
                "success": False,
                "error": error_detail,
                "status_code": e.response.status_code if e.response else 500
            }
            
        except requests.exceptions.RequestException as e:
            return {
                "success": False,
                "error": f"Connection error: {str(e)}",
                "status_code": 0
            }

    # ========================================================================
    # AUTHENTICATION (For future use)
    # ========================================================================

    def login(self, username: str, password: str) -> Dict:
        """Login to get auth token"""
        logger.info(f"Logging in as: {username}")
        
        payload = {
            "username": username,
            "password": password
        }
        
        response = self._request("POST", "/api/auth/login", json=payload)
        
        if response.get('success'):
            token = response.get('data', {}).get('access_token')
            if token:
                self.session.headers.update({"Authorization": f"Bearer {token}"})
                logger.info("Login successful")
        
        return response

    def register(self, email: str, username: str, password: str) -> Dict:
        """Register new user"""
        logger.info(f"Registering user: {username}")
        
        payload = {
            "email": email,
            "username": username,
            "password": password
        }
        
        return self._request("POST", "/api/auth/register", json=payload)
