"""
Magic: The Gathering API Integration for ScanBoss

Adds MTG-specific endpoints to the existing APIClient
"""

import requests
import logging
from typing import Dict, Any, Optional
from datetime import datetime

logger = logging.getLogger(__name__)


class MagicAPIClient:
    """
    Magic: The Gathering API Client
    Extends VendorBoss API for MTG card scanning
    """
    
    def __init__(self, base_url: str = "http://localhost:8000", api_key: Optional[str] = None):
        self.base_url = base_url
        self.timeout = 10
        self.session = requests.Session()
        
        if api_key:
            self.session.headers.update({"X-API-Key": api_key})
        
        logger.info(f"MagicAPIClient initialized for {self.base_url}")
    
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
    # MAGIC CARD SCANNING
    # ========================================================================
    
    def add_scanned_card(self, card_data: Dict) -> Dict:
        """
        Add a scanned Magic card to inventory
        
        Args:
            card_data: {
                # From VGG16 detection
                'card_id': 'm20-129',
                'confidence': 0.732,
                
                # From Scryfall
                'name': 'Chandra's Embercat',
                'set': 'm20',
                'set_name': 'Core Set 2020',
                'collector_number': '129',
                'type_line': 'Creature — Elemental Cat',
                'mana_cost': '{1}{R}',
                'rarity': 'Common',
                'image_url': 'https://...',
                'prices': {
                    'usd': '0.25',
                    'usd_foil': '0.50'
                },
                'oracle_text': '...',
                'power': '2',
                'toughness': '2',
                'scryfall_uri': 'https://...',
                
                # User input
                'condition': 'Near Mint',  # or 'Lightly Played', etc.
                'quantity': 1,
                'is_foil': False,
                
                # Metadata
                'scanned_at': '2026-02-22T18:30:00Z',
                'scanner_version': 'ScanBoss AI v1.0'
            }
        
        Returns:
            {
                'success': True,
                'data': {
                    'inventory_id': 'uuid',
                    'card': {...},
                    'message': 'Card added successfully'
                }
            }
        """
        logger.info(f"Adding scanned card: {card_data.get('name', 'Unknown')}")
        
        return self._request("POST", "/api/inventory/magic/scan", json=card_data)
    
    def validate_scan(self, card_data: Dict) -> Dict:
        """
        Validate a scanned card before adding to inventory
        
        Checks:
        - Confidence threshold met
        - Card exists in Scryfall
        - Price is reasonable (not outlier)
        - Set code is valid
        
        Returns validation result without adding to inventory
        """
        logger.info(f"Validating scan: {card_data.get('card_id', 'Unknown')}")
        
        return self._request("POST", "/api/inventory/magic/validate", json=card_data)
    
    def bulk_add_scans(self, cards: list) -> Dict:
        """
        Add multiple scanned cards in one batch
        
        Args:
            cards: List of card_data dicts
        
        Returns:
            {
                'success': True,
                'data': {
                    'added': 42,
                    'failed': 0,
                    'failures': []
                }
            }
        """
        logger.info(f"Bulk adding {len(cards)} scanned cards")
        
        return self._request("POST", "/api/inventory/magic/scan/bulk", json={'cards': cards})
    
    # ========================================================================
    # INVENTORY MANAGEMENT
    # ========================================================================
    
    def get_inventory(self, filters: Optional[Dict] = None, page: int = 1, per_page: int = 50) -> Dict:
        """
        Get Magic inventory with filters
        
        Args:
            filters: {
                'set': 'm20',
                'rarity': 'Rare',
                'min_price': 5.00,
                'max_price': 50.00,
                'condition': 'Near Mint',
                'is_foil': False
            }
            page: Page number
            per_page: Items per page
        """
        logger.info(f"Fetching Magic inventory (page {page})")
        
        params = {'page': page, 'per_page': per_page}
        if filters:
            params.update(filters)
        
        return self._request("GET", "/api/inventory/magic", params=params)
    
    def search_inventory(self, query: str) -> Dict:
        """
        Search inventory by card name
        
        Args:
            query: Card name (partial match OK)
        """
        logger.info(f"Searching inventory: {query}")
        
        return self._request("GET", f"/api/inventory/magic/search", params={'q': query})
    
    def update_card(self, inventory_id: str, updates: Dict) -> Dict:
        """
        Update inventory item
        
        Args:
            inventory_id: UUID of inventory item
            updates: {
                'quantity': 3,
                'condition': 'Lightly Played',
                'price_override': 12.50
            }
        """
        logger.info(f"Updating inventory item: {inventory_id}")
        
        return self._request("PATCH", f"/api/inventory/magic/{inventory_id}", json=updates)
    
    def delete_card(self, inventory_id: str) -> Dict:
        """Delete inventory item"""
        logger.info(f"Deleting inventory item: {inventory_id}")
        
        return self._request("DELETE", f"/api/inventory/magic/{inventory_id}")
    
    # ========================================================================
    # STATISTICS & REPORTS
    # ========================================================================
    
    def get_stats(self) -> Dict:
        """
        Get inventory statistics
        
        Returns:
            {
                'total_cards': 1523,
                'total_value': 4523.50,
                'by_set': {...},
                'by_rarity': {...},
                'top_value_cards': [...]
            }
        """
        logger.info("Fetching inventory stats")
        
        return self._request("GET", "/api/inventory/magic/stats")
    
    def get_scan_history(self, limit: int = 100) -> Dict:
        """
        Get recent scan history
        
        Returns list of recent scans with timestamps
        """
        logger.info(f"Fetching scan history (limit: {limit})")
        
        return self._request("GET", "/api/inventory/magic/scans/history", params={'limit': limit})
    
    # ========================================================================
    # PRICING & MARKET DATA
    # ========================================================================
    
    def refresh_prices(self, inventory_ids: Optional[list] = None) -> Dict:
        """
        Refresh prices from Scryfall
        
        Args:
            inventory_ids: Specific items to refresh, or None for all
        """
        logger.info("Refreshing prices from Scryfall")
        
        payload = {'inventory_ids': inventory_ids} if inventory_ids else {}
        
        return self._request("POST", "/api/inventory/magic/prices/refresh", json=payload)
    
    def get_price_history(self, card_id: str, days: int = 30) -> Dict:
        """
        Get price history for a card
        
        Args:
            card_id: 'm20-129'
            days: Days of history
        """
        logger.info(f"Fetching price history: {card_id}")
        
        return self._request("GET", f"/api/inventory/magic/prices/history/{card_id}", 
                           params={'days': days})
    
    # ========================================================================
    # AUTHENTICATION
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
    
    def set_api_key(self, api_key: str):
        """Set API key for authenticated requests"""
        self.session.headers.update({"X-API-Key": api_key})
        logger.info("API key set")
