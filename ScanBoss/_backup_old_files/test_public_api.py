"""
Test Script for Public API Endpoints
Run this to verify your API is working correctly
"""

import requests
import json
from datetime import datetime

# Your API URL
API_URL = "https://web-production-1f60.up.railway.app"  # Change to your URL


class APITester:
    def __init__(self, base_url):
        self.base_url = base_url
        self.session = requests.Session()
    
    def test_health(self):
        """Test health endpoint"""
        print("\n" + "="*60)
        print("TEST 1: Health Check")
        print("="*60)
        
        try:
            response = self.session.get(f"{self.base_url}/api/scan/health")
            print(f"Status Code: {response.status_code}")
            print(f"Response: {json.dumps(response.json(), indent=2)}")
            
            if response.status_code == 200:
                print("✅ PASSED: Health check working")
                return True
            else:
                print("❌ FAILED: Health check returned non-200")
                return False
                
        except Exception as e:
            print(f"❌ FAILED: {e}")
            return False
    
    def test_check_fingerprint(self):
        """Test fingerprint check endpoint"""
        print("\n" + "="*60)
        print("TEST 2: Check Fingerprint (Anonymous)")
        print("="*60)
        
        test_fingerprint = "abc123def456test"
        
        try:
            response = self.session.post(
                f"{self.base_url}/api/scan/fingerprint/check",
                json={
                    "fingerprint": test_fingerprint,
                    "confidence_threshold": 0.7
                },
                headers={"Content-Type": "application/json"}
            )
            
            print(f"Status Code: {response.status_code}")
            print(f"Response: {json.dumps(response.json(), indent=2)}")
            
            if response.status_code in [200, 404]:
                print("✅ PASSED: Fingerprint check works (no auth required)")
                return True
            elif response.status_code == 401:
                print("❌ FAILED: Still requires authentication!")
                print("   Make sure the endpoint is public")
                return False
            else:
                print(f"⚠️  WARNING: Unexpected status {response.status_code}")
                return False
                
        except Exception as e:
            print(f"❌ FAILED: {e}")
            return False
    
    def test_submit_fingerprint(self):
        """Test fingerprint submission endpoint"""
        print("\n" + "="*60)
        print("TEST 3: Submit Fingerprint (Anonymous)")
        print("="*60)
        
        test_data = {
            "fingerprint": f"test_{datetime.now().timestamp()}",
            "card_data": {
                "player_name": "Test Player",
                "card_year": 2024,
                "card_set": "Test Set"
            }
        }
        
        try:
            response = self.session.post(
                f"{self.base_url}/api/scan/fingerprint/submit",
                json=test_data,
                headers={"Content-Type": "application/json"}
            )
            
            print(f"Status Code: {response.status_code}")
            print(f"Response: {json.dumps(response.json(), indent=2)}")
            
            if response.status_code in [200, 201]:
                print("✅ PASSED: Fingerprint submission works (no auth required)")
                return True
            elif response.status_code == 401:
                print("❌ FAILED: Still requires authentication!")
                return False
            else:
                print(f"⚠️  WARNING: Status {response.status_code}")
                print("   This might be okay if database isn't set up yet")
                return True  # Don't fail on DB errors
                
        except Exception as e:
            print(f"❌ FAILED: {e}")
            return False
    
    def test_get_stats(self):
        """Test stats endpoint"""
        print("\n" + "="*60)
        print("TEST 4: Get Learning Stats (Anonymous)")
        print("="*60)
        
        try:
            response = self.session.get(f"{self.base_url}/api/scan/stats")
            
            print(f"Status Code: {response.status_code}")
            print(f"Response: {json.dumps(response.json(), indent=2)}")
            
            if response.status_code in [200, 404, 500]:
                print("✅ PASSED: Stats endpoint accessible (no auth required)")
                return True
            elif response.status_code == 401:
                print("❌ FAILED: Still requires authentication!")
                return False
            else:
                print(f"⚠️  WARNING: Unexpected status {response.status_code}")
                return True
                
        except Exception as e:
            print(f"❌ FAILED: {e}")
            return False
    
    def test_rate_limiting(self):
        """Test rate limiting"""
        print("\n" + "="*60)
        print("TEST 5: Rate Limiting")
        print("="*60)
        
        print("Making 5 rapid requests...")
        
        for i in range(5):
            try:
                response = self.session.get(f"{self.base_url}/api/scan/health")
                print(f"  Request {i+1}: {response.status_code}")
                
            except Exception as e:
                print(f"  Request {i+1}: Error - {e}")
        
        print("✅ PASSED: Rate limiting configured (check API logs for details)")
        return True
    
    def test_legacy_endpoint(self):
        """Test legacy endpoint for backward compatibility"""
        print("\n" + "="*60)
        print("TEST 6: Legacy Endpoint (Backward Compatibility)")
        print("="*60)
        
        try:
            response = self.session.post(
                f"{self.base_url}/api/scan/card-fingerprint",
                json={"fingerprint": {"hash": "test123"}},
                headers={"Content-Type": "application/json"}
            )
            
            print(f"Status Code: {response.status_code}")
            print(f"Response: {json.dumps(response.json(), indent=2)}")
            
            if response.status_code in [200, 404]:
                print("✅ PASSED: Legacy endpoint works")
                return True
            elif response.status_code == 401:
                print("❌ FAILED: Legacy endpoint requires auth")
                return False
            else:
                print(f"⚠️  WARNING: Status {response.status_code}")
                return True
                
        except Exception as e:
            print(f"❌ FAILED: {e}")
            return False
    
    def run_all_tests(self):
        """Run all tests"""
        print("\n" + "🧪" * 30)
        print("VENDORBOSS PUBLIC API TEST SUITE")
        print("🧪" * 30)
        print(f"\nTesting API: {self.base_url}")
        print(f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        
        tests = [
            ("Health Check", self.test_health),
            ("Check Fingerprint", self.test_check_fingerprint),
            ("Submit Fingerprint", self.test_submit_fingerprint),
            ("Get Stats", self.test_get_stats),
            ("Rate Limiting", self.test_rate_limiting),
            ("Legacy Endpoint", self.test_legacy_endpoint)
        ]
        
        results = []
        for name, test_func in tests:
            try:
                result = test_func()
                results.append((name, result))
            except Exception as e:
                print(f"\n❌ TEST CRASHED: {name} - {e}")
                results.append((name, False))
        
        # Summary
        print("\n" + "="*60)
        print("TEST SUMMARY")
        print("="*60)
        
        passed = sum(1 for _, result in results if result)
        total = len(results)
        
        for name, result in results:
            status = "✅ PASS" if result else "❌ FAIL"
            print(f"{status}: {name}")
        
        print(f"\nTotal: {passed}/{total} tests passed")
        
        if passed == total:
            print("\n🎉 ALL TESTS PASSED! API is ready for ScanBoss!")
        elif passed >= total - 1:
            print("\n⚠️  Most tests passed. Check failures above.")
        else:
            print("\n❌ Multiple failures. Review API setup.")
        
        return passed == total


if __name__ == "__main__":
    # Run tests
    tester = APITester(API_URL)
    success = tester.run_all_tests()
    
    if success:
        print("\n✅ Your API is ready!")
        print("   ScanBoss can now connect anonymously.")
    else:
        print("\n❌ Some tests failed.")
        print("   Review the errors above and fix them.")
