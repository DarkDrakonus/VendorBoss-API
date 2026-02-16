import json
import os
import logging
from typing import Dict, Any, Optional

logger = logging.getLogger(__name__)

DEFAULT_CACHE_FILE = "learning_model.json"

class LocalCache:
    """Handles saving and loading the fleet learning model to a local file."""

    def __init__(self, cache_file: str = DEFAULT_CACHE_FILE):
        self.cache_file = cache_file
        self.model_data: Dict[str, Any] = {
            "version": "0.0.0",
            "timestamp": "",
            "known_cards": {}
        }

    def load_model(self) -> bool:
        """Loads the learning model from the local cache file."""
        if not os.path.exists(self.cache_file):
            logger.warning(f"Local cache file not found: {self.cache_file}. A new one will be created.")
            return False
        
        try:
            with open(self.cache_file, 'r') as f:
                data = json.load(f)
            
            # Basic validation
            if 'version' not in data or 'known_cards' not in data:
                raise ValueError("Invalid cache file format.")

            # Convert list to a dictionary for fast lookups
            if isinstance(data["known_cards"], list):
                data["known_cards"] = {item['fingerprint']: item for item in data["known_cards"]}

            self.model_data = data
            logger.info(f"Successfully loaded local learning model version {self.get_version()} with {self.get_card_count()} cards.")
            return True
        except (json.JSONDecodeError, ValueError, IOError) as e:
            logger.error(f"Failed to load or parse local cache file: {e}. Starting fresh.", exc_info=True)
            # In case of corruption, start with an empty model
            self._reset_model()
            return False

    def save_model(self, version: str, timestamp: str, known_cards: list):
        """Saves the learning model to the cache file."""
        try:
            self.model_data["version"] = version
            self.model_data["timestamp"] = timestamp
            # Store as a dictionary for fast lookups when loaded next time
            self.model_data["known_cards"] = {item['fingerprint']: item for item in known_cards}

            with open(self.cache_file, 'w') as f:
                json.dump(self.model_data, f, indent=2)
            
            logger.info(f"Saved local learning model version {version} with {len(known_cards)} cards.")
        except IOError as e:
            logger.error(f"Failed to write to local cache file: {e}", exc_info=True)

    def get_version(self) -> str:
        """Returns the version of the currently loaded model."""
        return self.model_data.get("version", "0.0.0")

    def get_timestamp(self) -> str:
        """Returns the timestamp of the currently loaded model."""
        return self.model_data.get("timestamp", "")
    
    def get_card_count(self) -> int:
        """Returns the number of cards in the local model."""
        return len(self.model_data.get("known_cards", {}))

    def check_fingerprint(self, fingerprint: str) -> Optional[Dict]:
        """Performs a high-speed, local check for a fingerprint."""
        card = self.model_data["known_cards"].get(fingerprint)
        if card:
            logger.info(f"Local cache hit for fingerprint {fingerprint[:10]}...")
            return {"known": True, "card_data": card.get('card_data', {})}
        return None
    
    def get_fingerprint(self, fingerprint: str) -> Optional[Dict]:
        """Get card data for a fingerprint from local cache."""
        card = self.model_data["known_cards"].get(fingerprint)
        if card:
            logger.info(f"Local cache hit for fingerprint {fingerprint[:10]}...")
            return card.get('card_data', {})
        return None
    
    def save_fingerprint(self, fingerprint: str, card_data: Dict):
        """Save a fingerprint and card data to local cache."""
        self.model_data["known_cards"][fingerprint] = {
            "fingerprint": fingerprint,
            "card_data": card_data
        }
        # Optionally save to disk immediately
        try:
            with open(self.cache_file, 'w') as f:
                json.dump(self.model_data, f, indent=2)
            logger.info(f"Saved fingerprint {fingerprint[:10]}... to local cache")
        except IOError as e:
            logger.error(f"Failed to save fingerprint to cache: {e}")

    def _reset_model(self):
        """Resets the model to a default empty state."""
        self.model_data = {
            "version": "0.0.0",
            "timestamp": "",
            "known_cards": {}
        }
