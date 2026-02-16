import { useState } from 'react'
import './App.css'

// CHANGE THIS to your Mac's IP address
// Run: ifconfig en0 | grep "inet " | awk '{print $2}'
const API_URL = 'http://192.168.1.100:8000'  // <-- UPDATE THIS IP!

function App() {
  const [selectedImage, setSelectedImage] = useState(null)
  const [imagePreview, setImagePreview] = useState(null)
  const [identifying, setIdentifying] = useState(false)
  const [result, setResult] = useState(null)
  const [error, setError] = useState(null)

  const handleImageSelect = (e) => {
    const file = e.target.files[0]
    if (file) {
      setSelectedImage(file)
      setImagePreview(URL.createObjectURL(file))
      setResult(null)
      setError(null)
    }
  }

  const identifyCard = async () => {
    if (!selectedImage) return

    setIdentifying(true)
    setError(null)

    try {
      // TODO: Generate fingerprint from image
      // For now, this is a placeholder - you'll need the C++ fingerprint generator
      
      // Mock fingerprint data for testing the API
      const mockFingerprint = {
        fingerprint_hash: 'a'.repeat(64), // 64 char hash
        components: {
          border: '1'.repeat(16),
          name_region: '2'.repeat(16),
          color_zones: '3'.repeat(16),
          texture: '4'.repeat(16),
          layout: '5'.repeat(16),
          quadrant_0_0: 'a'.repeat(16),
          quadrant_0_1: 'b'.repeat(16),
          quadrant_0_2: 'c'.repeat(16),
          quadrant_1_0: 'd'.repeat(16),
          quadrant_1_1: 'e'.repeat(16),
          quadrant_1_2: 'f'.repeat(16),
          quadrant_2_0: 'g'.repeat(16),
          quadrant_2_1: 'h'.repeat(16),
          quadrant_2_2: 'i'.repeat(16),
        }
      }

      const response = await fetch(`${API_URL}/api/fingerprints/identify`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(mockFingerprint)
      })

      const data = await response.json()
      setResult(data)
      
      if (!data.found) {
        setError('Card not identified. This card may not be in our database yet.')
      }
    } catch (err) {
      setError('Failed to identify card: ' + err.message)
      console.error(err)
    } finally {
      setIdentifying(false)
    }
  }

  const confirmIdentification = async (confirmed) => {
    if (!result || !result.found) return

    try {
      const response = await fetch(`${API_URL}/api/fingerprints/confirm`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          fingerprint_hash: 'a'.repeat(64), // Same hash used for identification
          confirmed: confirmed
        })
      })

      const data = await response.json()
      alert(data.message + ` (New confidence: ${data.new_confidence})`)
      
      // Reset for next scan
      setSelectedImage(null)
      setImagePreview(null)
      setResult(null)
    } catch (err) {
      setError('Failed to confirm: ' + err.message)
    }
  }

  return (
    <div className="app">
      <header>
        <h1>VendorBoss 2.0</h1>
        <p>Card Identification System</p>
      </header>

      <main>
        {/* Image Upload */}
        <div className="upload-section">
          <label htmlFor="image-upload" className="upload-label">
            {imagePreview ? (
              <img src={imagePreview} alt="Selected card" className="preview-image" />
            ) : (
              <div className="upload-placeholder">
                <p>📸</p>
                <p>Click to upload or take photo</p>
              </div>
            )}
          </label>
          <input
            id="image-upload"
            type="file"
            accept="image/*"
            capture="environment"
            onChange={handleImageSelect}
            style={{ display: 'none' }}
          />
        </div>

        {/* Identify Button */}
        {selectedImage && !result && (
          <button 
            className="identify-button"
            onClick={identifyCard}
            disabled={identifying}
          >
            {identifying ? 'Identifying...' : 'Identify Card'}
          </button>
        )}

        {/* Error Message */}
        {error && (
          <div className="error-message">
            ⚠️ {error}
          </div>
        )}

        {/* Results */}
        {result && result.found && (
          <div className="result-card">
            <h2>Card Identified!</h2>
            
            <div className="card-info">
              <h3>{result.product.card_name}</h3>
              <div className="detail-row">
                <span className="label">Set:</span>
                <span>{result.product.card_set} ({result.product.card_year})</span>
              </div>
              <div className="detail-row">
                <span className="label">Number:</span>
                <span>{result.product.card_number || 'N/A'}</span>
              </div>
              <div className="detail-row">
                <span className="label">Rarity:</span>
                <span>{result.product.rarity || 'N/A'}</span>
              </div>
              {result.product.element && (
                <div className="detail-row">
                  <span className="label">Element:</span>
                  <span>{result.product.element}</span>
                </div>
              )}
            </div>

            {/* Pricing */}
            {(result.pricing?.raw_nm_market || result.pricing?.psa_10) && (
              <div className="pricing-info">
                <h4>Market Pricing</h4>
                {result.pricing.raw_nm_market && (
                  <div className="price-row">
                    <span>Raw (NM):</span>
                    <span className="price">${result.pricing.raw_nm_market.average}</span>
                  </div>
                )}
                {result.pricing.psa_10 && (
                  <div className="price-row">
                    <span>PSA 10:</span>
                    <span className="price">${result.pricing.psa_10.average}</span>
                  </div>
                )}
              </div>
            )}

            {/* Match Quality */}
            <div className="match-quality">
              <div className="quality-stat">
                <span>Confidence:</span>
                <span>{(result.match_quality.confidence_score * 100).toFixed(0)}%</span>
              </div>
              <div className="quality-stat">
                <span>Times Matched:</span>
                <span>{result.match_quality.times_matched}</span>
              </div>
              {result.match_quality.verified && (
                <div className="verified-badge">✓ Verified</div>
              )}
            </div>

            {/* Confirmation Buttons */}
            <div className="confirmation-buttons">
              <button 
                className="confirm-button correct"
                onClick={() => confirmIdentification(true)}
              >
                ✓ Correct
              </button>
              <button 
                className="confirm-button incorrect"
                onClick={() => confirmIdentification(false)}
              >
                ✗ Incorrect
              </button>
            </div>
          </div>
        )}

        {/* Not Found */}
        {result && !result.found && (
          <div className="not-found">
            <h2>Card Not Found</h2>
            <p>{result.message}</p>
            <button 
              className="reset-button"
              onClick={() => {
                setSelectedImage(null)
                setImagePreview(null)
                setResult(null)
                setError(null)
              }}
            >
              Try Another Card
            </button>
          </div>
        )}
      </main>

      <footer>
        <p>VendorBoss 2.0 - Final Fantasy TCG Proof of Concept</p>
        <p className="note">
          Note: Fingerprint generation from images is not yet implemented.
          This demo uses mock fingerprint data.
        </p>
      </footer>
    </div>
  )
}

export default App
