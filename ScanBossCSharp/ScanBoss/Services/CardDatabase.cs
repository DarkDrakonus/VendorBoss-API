using System;
using System.IO;
using MessagePack;
using ScanBoss.Models;

namespace ScanBoss.Services
{
    public class CardDatabase
    {
        private float[][]? _vectors;
        private string[]? _cardIds;
        private readonly string _game;
        private readonly ScryfallService? _scryfallService;

        public int CardCount => _cardIds?.Length ?? 0;
        public bool IsLoaded => _vectors != null && _cardIds != null;

        public CardDatabase(string game, ScryfallService? scryfallService = null)
        {
            _game = game;
            _scryfallService = scryfallService;
        }

        public bool LoadFromMessagePack(string msgpackPath)
        {
            try
            {
                Console.WriteLine($"[CardDatabase] Loading from: {msgpackPath}");
                
                if (!File.Exists(msgpackPath))
                {
                    Console.WriteLine($"[CardDatabase] ✗ File not found!");
                    return false;
                }

                var fileInfo = new FileInfo(msgpackPath);
                Console.WriteLine($"[CardDatabase] File size: {fileInfo.Length / (1024*1024)}MB");

                // Read MessagePack file
                var bytes = File.ReadAllBytes(msgpackPath);
                var data = MessagePackSerializer.Deserialize<DatabaseData>(bytes);
                
                if (data == null || data.Vectors == null || data.CardIds == null)
                {
                    Console.WriteLine("[CardDatabase] ✗ Invalid format");
                    return false;
                }

                // Convert binary vectors back to float arrays
                int vectorDim = data.VectorDimension;
                int cardCount = data.CardCount;
                
                Console.WriteLine($"[CardDatabase] Unpacking {cardCount:N0} vectors...");
                
                _vectors = new float[cardCount][];
                var vectorBytes = data.Vectors;
                
                for (int i = 0; i < cardCount; i++)
                {
                    _vectors[i] = new float[vectorDim];
                    Buffer.BlockCopy(vectorBytes, i * vectorDim * 4, _vectors[i], 0, vectorDim * 4);
                }
                
                _cardIds = data.CardIds;
                
                Console.WriteLine($"[CardDatabase] ✓ Loaded {CardCount:N0} cards from {_game}");
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[CardDatabase] ✗ Error: {ex.Message}");
                Console.WriteLine(ex.StackTrace);
                return false;
            }
        }

        public (string cardId, float confidence) FindBestMatch(float[] queryVector)
        {
            if (_vectors == null || _cardIds == null)
                return (string.Empty, 0f);

            float bestSimilarity = -1f;
            int bestIndex = -1;

            for (int i = 0; i < _vectors.Length; i++)
            {
                float similarity = CosineSimilarity(queryVector, _vectors[i]);
                
                if (similarity > bestSimilarity)
                {
                    bestSimilarity = similarity;
                    bestIndex = i;
                }
            }

            if (bestIndex >= 0)
            {
                return (_cardIds[bestIndex], bestSimilarity);
            }

            return (string.Empty, 0f);
        }

        public CardInfo? GetCardInfo(string cardId)
        {
            var card = new CardInfo
            {
                CardId = cardId,
                Game = _game,
                Name = cardId
            };

            if (_game == "magic" && _scryfallService != null)
            {
                var scryfallCard = _scryfallService.GetCardAsync(cardId).Result;
                if (scryfallCard != null)
                {
                    card.Name = scryfallCard.Name ?? cardId;
                    card.Set = scryfallCard.Set ?? string.Empty;
                    card.SetName = scryfallCard.SetName ?? string.Empty;
                    card.TypeLine = scryfallCard.TypeLine ?? string.Empty;
                    card.Rarity = scryfallCard.Rarity ?? string.Empty;
                    card.ImageUrl = scryfallCard.ImageUrl;
                    card.Prices = scryfallCard.Prices;
                }
            }

            return card;
        }

        private static float CosineSimilarity(float[] a, float[] b)
        {
            float dotProduct = 0f;
            float normA = 0f;
            float normB = 0f;

            for (int i = 0; i < a.Length; i++)
            {
                dotProduct += a[i] * b[i];
                normA += a[i] * a[i];
                normB += b[i] * b[i];
            }

            return dotProduct / (MathF.Sqrt(normA) * MathF.Sqrt(normB));
        }

        [MessagePackObject]
        private class DatabaseData
        {
            [Key("game")]
            public string? Game { get; set; }
            
            [Key("card_count")]
            public int CardCount { get; set; }
            
            [Key("vector_dimension")]
            public int VectorDimension { get; set; }
            
            [Key("vectors")]
            public byte[]? Vectors { get; set; }
            
            [Key("card_ids")]
            public string[]? CardIds { get; set; }
        }
    }
}
