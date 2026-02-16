"""
API Configuration for ScanBoss - VendorBoss 2.0
"""

# VendorBoss 2.0 API Configuration
API_CONFIG = {
    "base_url": "http://localhost:8000",  # Local VendorBoss 2.0 API
    "timeout": 10,  # seconds
    "api_key": None,  # Set this for ScanBoss-specific endpoints (submit, model download)
}

# For production, update to:
# API_CONFIG = {
#     "base_url": "https://api.vendorboss.com",
#     "timeout": 10,
#     "api_key": "YOUR_SCANBOSS_API_KEY_HERE",
# }
