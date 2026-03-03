using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Threading.Tasks;
using Newtonsoft.Json;

namespace ScanBoss.Services
{
    public class ScryfallCard
    {
        [JsonProperty("name")]
        public string? Name { get; set; }

        [JsonProperty("set")]
        public string? Set { get; set; }

        [JsonProperty("set_name")]
        public string? SetName { get; set; }

        [JsonProperty("type_line")]
        public string? TypeLine { get; set; }

        [JsonProperty("rarity")]
        public string? Rarity { get; set; }

        [JsonProperty("collector_number")]
        public string? CollectorNumber { get; set; }

        [JsonProperty("image_uris")]
        public ImageUris? Images { get; set; }

        [JsonProperty("prices")]
        public Dictionary<string, string?>? PricesRaw { get; set; }

        public string? ImageUrl => Images?.Normal ?? Images?.Large;
        
        public Dictionary<string, string?> Prices => PricesRaw ?? new();
    }

    public class ImageUris
    {
        [JsonProperty("normal")]
        public string? Normal { get; set; }

        [JsonProperty("large")]
        public string? Large { get; set; }
    }

    public class ScryfallService
    {
        private readonly HttpClient _httpClient;
        private const string BaseUrl = "https://api.scryfall.com";

        public ScryfallService()
        {
            _httpClient = new HttpClient();
            _httpClient.DefaultRequestHeaders.Add("User-Agent", "ScanBoss/1.0");
        }

        public async Task<ScryfallCard?> GetCardAsync(string cardId)
        {
            try
            {
                // Card ID format: "set-number" (e.g., "m20-129")
                var parts = cardId.Split('-');
                if (parts.Length != 2)
                    return null;

                var setCode = parts[0];
                var collectorNumber = parts[1];

                var url = $"{BaseUrl}/cards/{setCode}/{collectorNumber}";
                var response = await _httpClient.GetAsync(url);

                if (!response.IsSuccessStatusCode)
                    return null;

                var json = await response.Content.ReadAsStringAsync();
                return JsonConvert.DeserializeObject<ScryfallCard>(json);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Scryfall API error: {ex.Message}");
                return null;
            }
        }
    }
}
