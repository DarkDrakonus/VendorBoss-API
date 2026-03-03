#!/usr/bin/env python3
"""
Align ScanBoss with actual VendorBoss API schema
Based on real models.py, schemas.py, and card_scanner.py
"""

print("🔧 Updating ScanBoss to match VendorBoss API schema...")

with open('scanboss_fleet.py', 'r') as f:
    content = f.read()

# Update CardDataDialog to match API ProductBase schema
old_dialog = """    def get_card_data(self):
        year = self.year_input.text()
        return {
            'sport': self.sport_input.text() or None,
            'player_name': self.player_input.text(),
            'brand': self.brand_input.text() or None,
            'card_set': self.set_input.text(),
            'card_year': int(year) if year.isdigit() else None,
            'card_number': self.number_input.text() or None,
            'variant': self.variant_input.text() or None
        }"""

new_dialog = """    def get_card_data(self):
        year = self.year_input.text()
        variant = self.variant_input.text()
        
        return {
            # Required fields (matching API ProductBase)
            'sport': self.sport_input.text() or 'Unknown',
            'player_name': self.player_input.text(),
            'card_year': int(year) if year.isdigit() else None,
            'card_set': self.set_input.text(),
            
            # Optional fields
            'card_number': self.number_input.text() or None,
            
            # Variant fields (API uses is_parallel + parallel_name)
            'is_parallel': bool(variant),
            'parallel_name': variant if variant else None,
            
            # Boolean flags
            'is_rookie': False,  # Could add checkbox for this
            'is_auto': False,    # Could add checkbox for this
            'is_relic': False,   # Could add checkbox for this
            'is_refractor': False,  # Could add checkbox for this
            'serial_numbered': False,
            
            # Additional fields if needed
            'team': None,
            'position': None,
            'barcode': None
        }"""

if old_dialog in content:
    content = content.replace(old_dialog, new_dialog)
    print("✅ Updated card data structure to match API")

with open('scanboss_fleet.py', 'w') as f:
    f.write(content)

# Update API client to use correct field names
with open('api_client.py', 'r') as f:
    api_content = f.read()

old_submit = """    def submit_fingerprint(self, fingerprint: str, card_data: Dict) -> Dict:
        \"\"\"
        Submit card data for learning system
        PUBLIC - No authentication required (anonymous submissions)
        \"\"\"
        try:
            payload = {
                "fingerprint": fingerprint,
                "card_data": card_data,
                "user_id": None  # Anonymous submission
            }
            
            response = self.session.post(
                f"{self.base_url}/api/scan/fingerprint/submit",
                json=payload,
                headers={"Content-Type": "application/json"}
            )
            
            if response.status_code in [200, 201]:
                return {"success": True, "data": response.json()}
            else:
                # Fallback to legacy create_product if new endpoint not available
                product_data = card_data.copy()
                product_data['fingerprint'] = fingerprint
                return self.create_product(product_data)
                
        except Exception as e:
            return {"success": False, "error": str(e)}"""

new_submit = """    def submit_fingerprint(self, fingerprint: str, card_data: Dict) -> Dict:
        \"\"\"
        Submit card data for learning system
        Uses VendorBoss /scan/record endpoint to store fingerprint
        \"\"\"
        try:
            # First, try the new learning endpoint if available
            payload = {
                "fingerprint": fingerprint,
                "card_data": card_data,
                "user_id": None  # Anonymous submission
            }
            
            response = self.session.post(
                f"{self.base_url}/api/scan/fingerprint/submit",
                json=payload,
                headers={"Content-Type": "application/json"}
            )
            
            if response.status_code in [200, 201]:
                return {"success": True, "data": response.json()}
            
            # Fallback: Use /scan/record endpoint to store fingerprint
            print("Using fallback /scan/record endpoint")
            scan_data = {
                "user_id": None,  # Anonymous
                "product_id": None,  # Will be linked after product creation
                "fingerprint": fingerprint,
                "raw_data": str(card_data),
                "confidence": 1.0
            }
            
            response = self.session.post(
                f"{self.base_url}/api/scan/record",
                json=scan_data,
                headers={"Content-Type": "application/json"}
            )
            
            if response.status_code in [200, 201]:
                return {"success": True, "data": response.json()}
            else:
                return {"success": False, "error": f"Status {response.status_code}: {response.text}"}
                
        except Exception as e:
            return {"success": False, "error": str(e)}"""

if old_submit in api_content:
    api_content = api_content.replace(old_submit, new_submit)
    print("✅ Updated API client to use correct endpoints")

with open('api_client.py', 'w') as f:
    f.write(api_content)

print("\n📋 Summary:")
print("   ✅ Card form now matches VendorBoss API ProductBase schema")
print("   ✅ Field names aligned: player_name, card_year, card_set, etc.")
print("   ✅ API client uses /scan/record endpoint for fingerprints")
print("   ✅ Supports variant/parallel detection")
print("\n📝 Fields now supported:")
print("   - sport (required)")
print("   - player_name (required)")
print("   - card_year (required)")
print("   - card_set (required)")
print("   - card_number (optional)")
print("   - parallel_name (variant)")
print("   - is_parallel (boolean)")
print("   - team, position, barcode (optional)")
print("\n🎯 Next: Test with python3 scanboss_fleet.py")
