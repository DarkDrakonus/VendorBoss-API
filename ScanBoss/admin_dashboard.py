#!/usr/bin/env python3
"""
ScanBoss Learning System - Admin Dashboard
Monitor the fleet learning system performance
"""

import requests
import json
from datetime import datetime
from typing import Dict
import sys


class LearningDashboard:
    """Simple command-line dashboard for monitoring"""
    
    def __init__(self, api_url: str = "https://web-production-1f60.up.railway.app"):
        self.api_url = api_url
        self.session = requests.Session()
    
    def get_stats(self) -> Dict:
        """Get system statistics"""
        try:
            response = self.session.get(f"{self.api_url}/api/scan/stats")
            if response.status_code == 200:
                return response.json()
            return {}
        except:
            return {}
    
    def get_recent_activity(self, hours: int = 24) -> list:
        """Get recent activity"""
        try:
            response = self.session.get(
                f"{self.api_url}/api/scan/activity/recent",
                params={"hours": hours, "limit": 20}
            )
            if response.status_code == 200:
                return response.json().get('activity', [])
            return []
        except:
            return []
    
    def display_dashboard(self):
        """Display the dashboard"""
        print("\n" + "=" * 60)
        print("📊  ScanBoss Learning System Dashboard")
        print("=" * 60)
        print(f"⏰  {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        
        # Get stats
        stats = self.get_stats()
        
        if stats:
            print("📈  System Statistics:")
            print(f"   Total Fingerprints: {stats.get('total_fingerprints', 0):,}")
            print(f"   ✓ Confirmed Cards: {stats.get('confirmed_cards', 0):,}")
            print(f"   📚 Learning Cards: {stats.get('learning_cards', 0):,}")
            print(f"   ⚠ Disputed Cards: {stats.get('disputed_cards', 0):,}")
            print(f"   📝 Total Submissions: {stats.get('total_submissions', 0):,}")
            
            avg_conf = stats.get('average_confidence', 0)
            print(f"   🎯 Average Confidence: {avg_conf:.1%}")
            
            # Calculate learning rate
            confirmed = stats.get('confirmed_cards', 0)
            total = stats.get('total_fingerprints', 1)
            learning_rate = (confirmed / total) * 100
            print(f"   📊 Learning Rate: {learning_rate:.1f}%")
            
            print()
        
        # Recent activity
        activity = self.get_recent_activity(hours=24)
        
        if activity:
            print("🔥  Recent Activity (Last 24 hours):")
            print(f"   {'Player':<25} {'Subs':<6} {'Conf':<8} {'Status':<12}")
            print(f"   {'-'*25} {'-'*6} {'-'*8} {'-'*12}")
            
            for item in activity[:10]:
                player = item.get('player', 'Unknown')[:24]
                subs = item.get('submissions', 0)
                conf = item.get('confidence', 0)
                status = item.get('status', '?')
                
                # Status emoji
                status_icon = {
                    'confirmed': '✓',
                    'learning': '📚',
                    'disputed': '⚠'
                }.get(status, '?')
                
                print(f"   {player:<25} {subs:<6} {conf:<7.1%} {status_icon} {status}")
            
            print()
        
        print("=" * 60)
        print("💡 Tips:")
        print("   • Confirmed cards appear instantly in all ScanBoss apps")
        print("   • Learning requires 3+ submissions with 80%+ agreement")
        print("   • Disputed cards need manual review")
        print("=" * 60 + "\n")
    
    def export_report(self, filename: str = "learning_report.txt"):
        """Export a text report"""
        stats = self.get_stats()
        activity = self.get_recent_activity(hours=168)  # Last week
        
        with open(filename, 'w') as f:
            f.write("ScanBoss Learning System Report\n")
            f.write(f"Generated: {datetime.now().isoformat()}\n")
            f.write("=" * 60 + "\n\n")
            
            f.write("System Statistics:\n")
            for key, value in stats.items():
                f.write(f"  {key}: {value}\n")
            
            f.write("\n\nRecent Activity (Last 7 days):\n")
            for item in activity:
                f.write(f"  {item}\n")
        
        print(f"✓ Report exported to {filename}")


def main():
    """Run the dashboard"""
    dashboard = LearningDashboard()
    
    if len(sys.argv) > 1 and sys.argv[1] == "--export":
        dashboard.export_report()
    else:
        dashboard.display_dashboard()


if __name__ == "__main__":
    main()
