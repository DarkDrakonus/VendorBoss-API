using System;
using System.Collections.Generic;
using System.Linq;
using Microsoft.ML.OnnxRuntime;
using Microsoft.ML.OnnxRuntime.Tensors;
using ScanBoss.Models;
using SkiaSharp;

namespace ScanBoss.Services
{
    public class VGG16Detector : IDisposable
    {
        private readonly InferenceSession _session;
        private readonly CardDatabase _database;
        private const int ImageSize = 224;

        public VGG16Detector(string modelPath, CardDatabase database)
        {
            _session = new InferenceSession(modelPath);
            _database = database;
        }

        public DetectionResult DetectCard(SKBitmap image, float confidenceThreshold = 0.6f)
        {
            var startTime = DateTime.Now;

            try
            {
                // Extract VGG16 features
                var features = ExtractFeatures(image);

                // Search database for best match
                var (cardId, confidence) = _database.FindBestMatch(features);

                if (confidence < confidenceThreshold)
                {
                    return new DetectionResult
                    {
                        Success = false,
                        ErrorMessage = $"Low confidence: {confidence:P1}"
                    };
                }

                // Get card info
                var cardInfo = _database.GetCardInfo(cardId);
                if (cardInfo != null)
                {
                    cardInfo.Confidence = (decimal)confidence;
                    
                    return new DetectionResult
                    {
                        Success = true,
                        Card = cardInfo,
                        ProcessingTime = DateTime.Now - startTime
                    };
                }

                return new DetectionResult
                {
                    Success = false,
                    ErrorMessage = "Card not found in database"
                };
            }
            catch (Exception ex)
            {
                return new DetectionResult
                {
                    Success = false,
                    ErrorMessage = ex.Message,
                    ProcessingTime = DateTime.Now - startTime
                };
            }
        }

        private float[] ExtractFeatures(SKBitmap image)
        {
            // Resize to 224x224
            var resized = image.Resize(new SKImageInfo(ImageSize, ImageSize), SKFilterQuality.High);
            if (resized == null)
                throw new Exception("Failed to resize image");

            // Convert to tensor [1, 224, 224, 3]
            var tensor = new DenseTensor<float>(new[] { 1, ImageSize, ImageSize, 3 });

            for (int y = 0; y < ImageSize; y++)
            {
                for (int x = 0; x < ImageSize; x++)
                {
                    var pixel = resized.GetPixel(x, y);
                    
                    // VGG16 preprocessing (ImageNet normalization)
                    tensor[0, y, x, 0] = (pixel.Red - 123.68f);
                    tensor[0, y, x, 1] = (pixel.Green - 116.779f);
                    tensor[0, y, x, 2] = (pixel.Blue - 103.939f);
                }
            }

            // Run inference
            var inputs = new List<NamedOnnxValue>
            {
                NamedOnnxValue.CreateFromTensor("input", tensor)
            };

            using var results = _session.Run(inputs);
            var output = results.First().AsEnumerable<float>().ToArray();

            return output;
        }

        public void Dispose()
        {
            _session?.Dispose();
        }
    }
}
