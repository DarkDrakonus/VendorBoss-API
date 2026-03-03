# Clean Up Instructions

The old WPF files (App.xaml, MainWindow.xaml) are still there.

Please manually delete these 4 files:
- ScanBoss/App.xaml
- ScanBoss/App.xaml.cs  
- ScanBoss/MainWindow.xaml
- ScanBoss/MainWindow.xaml.cs

Or run:
```bash
cd /Users/travisdewitt/Repos/VendorBoss2.0/ScanBossCSharp/ScanBoss
rm App.xaml App.xaml.cs MainWindow.xaml MainWindow.xaml.cs
```

The Avalonia files you want to keep are:
- App.axaml (note the 'a' - Avalonia)
- App.axaml.cs
- MainWindow.axaml  
- MainWindow.axaml.cs
- Program.cs

After deleting the old WPF files, run:
```bash
dotnet clean
dotnet restore
dotnet build
dotnet run --project ScanBoss
```
