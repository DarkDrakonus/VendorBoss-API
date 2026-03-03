using System;
using System.IO;
using System.Reflection;
using System.Collections.ObjectModel;
using ScanBoss.Models;
using ScanBoss.Services;

namespace ScanBoss.ViewModels
{
    public class MainViewModel : BaseViewModel
    {
        private string _selectedGame = "Magic: The Gathering";
        private string _statusMessage = "Ready";
        private int _cardCount;
        private CardDatabase? _currentDatabase;
        private readonly ScryfallService _scryfallService;

        public ObservableCollection<string> AvailableGames { get; } = new()
        {
            "Magic: The Gathering",
            "Final Fantasy TCG"
        };

        public string SelectedGame
        {
            get => _selectedGame;
            set
            {
                Console.WriteLine($"[ViewModel] Game changing to: {value}");
                if (SetProperty(ref _selectedGame, value))
                {
                    LoadGameDatabase();
                }
            }
        }

        public string StatusMessage
        {
            get => _statusMessage;
            set
            {
                SetProperty(ref _statusMessage, value);
                Console.WriteLine($"[ViewModel] Status: {value}");
            }
        }

        public int CardCount
        {
            get => _cardCount;
            set
            {
                SetProperty(ref _cardCount, value);
                Console.WriteLine($"[ViewModel] CardCount: {value}");
            }
        }

        public MainViewModel()
        {
            Console.WriteLine("[ViewModel] Constructor - Creating MainViewModel");
            _scryfallService = new ScryfallService();
            Console.WriteLine($"[ViewModel] Available games: {string.Join(", ", AvailableGames)}");
            LoadGameDatabase();
        }

        private void LoadGameDatabase()
        {
            Console.WriteLine($"[ViewModel] LoadGameDatabase for: {SelectedGame}");
            StatusMessage = $"Loading {SelectedGame}...";
            CardCount = 0;

            try
            {
                var gameKey = SelectedGame == "Magic: The Gathering" ? "magic" : "fftcg";
                
                // Get the application's base directory (where the .exe runs)
                var baseDir = AppDomain.CurrentDomain.BaseDirectory;
                var dbPath = Path.Combine(baseDir, "Models", $"vgg16_db_{gameKey}.msgpack");
                
                Console.WriteLine($"[ViewModel] Base directory: {baseDir}");
                Console.WriteLine($"[ViewModel] Database path: {dbPath}");
                Console.WriteLine($"[ViewModel] File exists: {File.Exists(dbPath)}");

                if (!File.Exists(dbPath))
                {
                    StatusMessage = $"✗ Database not found";
                    Console.WriteLine($"[ViewModel] ERROR: File not found!");
                    Console.WriteLine($"[ViewModel] Looking for: {dbPath}");
                    return;
                }

                var fileInfo = new FileInfo(dbPath);
                Console.WriteLine($"[ViewModel] File size: {fileInfo.Length / (1024*1024)}MB");

                _currentDatabase = new CardDatabase(gameKey, _scryfallService);
                
                if (_currentDatabase.LoadFromMessagePack(dbPath))
                {
                    CardCount = _currentDatabase.CardCount;
                    StatusMessage = $"✓ {CardCount:N0} cards loaded";
                    Console.WriteLine($"[ViewModel] ✓ SUCCESS! {CardCount:N0} cards loaded");
                }
                else
                {
                    StatusMessage = "✗ Failed to load";
                    Console.WriteLine($"[ViewModel] ✗ LoadFromMessagePack failed");
                }
            }
            catch (Exception ex)
            {
                StatusMessage = $"✗ Error: {ex.Message}";
                Console.WriteLine($"[ViewModel] ✗ EXCEPTION: {ex}");
            }
        }

        public CardDatabase? GetCurrentDatabase() => _currentDatabase;
    }
}
