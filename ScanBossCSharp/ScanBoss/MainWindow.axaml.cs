using Avalonia.Controls;
using Avalonia.Markup.Xaml;
using ScanBoss.ViewModels;
using System;
using System.ComponentModel;

namespace ScanBoss
{
    public partial class MainWindow : Window
    {
        private MainViewModel? _viewModel;
        private ComboBox? _gameComboBox;
        private TextBlock? _statusLabel;
        private TextBlock? _cardCountLabel;

        public MainWindow()
        {
            InitializeComponent();
            
            Console.WriteLine("=== MainWindow Initialization Starting ===");
            
            // Get controls by name
            _gameComboBox = this.FindControl<ComboBox>("GameComboBox");
            _statusLabel = this.FindControl<TextBlock>("StatusLabel");
            _cardCountLabel = this.FindControl<TextBlock>("CardCountLabel");
            
            Console.WriteLine($"Controls found:");
            Console.WriteLine($"  - ComboBox: {_gameComboBox != null}");
            Console.WriteLine($"  - StatusLabel: {_statusLabel != null}");
            Console.WriteLine($"  - CardCountLabel: {_cardCountLabel != null}");
            
            // Create ViewModel
            _viewModel = new MainViewModel();
            
            // Listen for property changes
            _viewModel.PropertyChanged += ViewModel_PropertyChanged;
            
            // Wire up ComboBox
            if (_gameComboBox != null)
            {
                _gameComboBox.ItemsSource = _viewModel.AvailableGames;
                _gameComboBox.SelectedItem = _viewModel.SelectedGame;
                _gameComboBox.SelectionChanged += (s, e) =>
                {
                    if (_gameComboBox.SelectedItem is string game)
                    {
                        Console.WriteLine($"[UI] ComboBox changed to: {game}");
                        _viewModel.SelectedGame = game;
                    }
                };
                
                Console.WriteLine($"ComboBox populated with {_viewModel.AvailableGames.Count} items");
                foreach (var game in _viewModel.AvailableGames)
                {
                    Console.WriteLine($"  - {game}");
                }
            }
            
            // Initial UI update
            UpdateUI();
            
            Console.WriteLine("=== MainWindow Initialization Complete ===\n");
        }

        private void ViewModel_PropertyChanged(object? sender, PropertyChangedEventArgs e)
        {
            Console.WriteLine($"[UI] Property changed: {e.PropertyName}");
            UpdateUI();
        }

        private void UpdateUI()
        {
            if (_viewModel == null) return;
            
            if (_statusLabel != null)
            {
                _statusLabel.Text = _viewModel.StatusMessage;
            }
            
            if (_cardCountLabel != null)
            {
                _cardCountLabel.Text = _viewModel.CardCount > 0 
                    ? $"✓ {_viewModel.CardCount:N0} cards" 
                    : "";
            }
        }

        private void InitializeComponent()
        {
            AvaloniaXamlLoader.Load(this);
        }
    }
}
