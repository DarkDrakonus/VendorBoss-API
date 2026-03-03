using System;
using System.Threading;
using System.Threading.Tasks;
using OpenCvSharp;
using SkiaSharp;

namespace ScanBoss.Services
{
    public class CameraService : IDisposable
    {
        private VideoCapture? _capture;
        private bool _isRunning;

        public event EventHandler<SKBitmap>? FrameCaptured;

        public bool Start(int cameraIndex = 0)
        {
            try
            {
                _capture = new VideoCapture(cameraIndex);
                _capture.Set(VideoCaptureProperties.FrameWidth, 1920);
                _capture.Set(VideoCaptureProperties.FrameHeight, 1080);

                _isRunning = true;
                Task.Run(() => CaptureLoop());

                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Camera error: {ex.Message}");
                return false;
            }
        }

        public void Stop()
        {
            _isRunning = false;
            _capture?.Release();
        }

        private void CaptureLoop()
        {
            using var frame = new Mat();

            while (_isRunning && _capture != null && _capture.IsOpened())
            {
                _capture.Read(frame);

                if (!frame.Empty())
                {
                    var bitmap = MatToSKBitmap(frame);
                    FrameCaptured?.Invoke(this, bitmap);
                }

                Thread.Sleep(30); // ~30 FPS
            }
        }

        public SKBitmap? CaptureFrame()
        {
            if (_capture == null || !_capture.IsOpened())
                return null;

            using var frame = new Mat();
            _capture.Read(frame);

            return frame.Empty() ? null : MatToSKBitmap(frame);
        }

        private static SKBitmap MatToSKBitmap(Mat mat)
        {
            // Convert Mat to byte array
            var bytes = new byte[mat.Total() * mat.ElemSize()];
            System.Runtime.InteropServices.Marshal.Copy(mat.Data, bytes, 0, bytes.Length);
            
            // Create SKBitmap
            var info = new SKImageInfo(mat.Width, mat.Height, SKColorType.Bgra8888);
            var bitmap = new SKBitmap(info);
            
            // Copy bytes to SKBitmap
            unsafe
            {
                var ptr = (byte*)bitmap.GetPixels();
                for (int i = 0; i < bytes.Length; i++)
                {
                    ptr[i] = bytes[i];
                }
            }
            
            return bitmap;
        }

        public void Dispose()
        {
            Stop();
            _capture?.Dispose();
        }
    }
}
