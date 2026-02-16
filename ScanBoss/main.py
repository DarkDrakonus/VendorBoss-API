"""
ScanBoss Application Launcher

This is the main entry point for the ScanBoss application.
Its sole responsibility is to initialize and run the application.
"""

import sys
from PyQt6.QtWidgets import QApplication

# Import the main application window from its new, organized location
from ui.main_window import ScanBossApp

def main():
    """Initializes and executes the PyQt application."""
    app = QApplication(sys.argv)
    window = ScanBossApp()
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    # Set a custom user agent for all network requests made by the app
    # This is good practice for identifying your application's traffic.
    import os
    os.environ["__APP_USER_AGENT__"] = "ScanBossDesktop/1.0"
    
    main()
