"""
Quick database setup for FFTCG bulk upload
Adds required reference data
"""
from database import get_db
import models

def setup_fftcg_database():
    """Add required reference data for FFTCG"""
    db = next(get_db())
    
    print("Setting up FFTCG database...")
    
    # Add product type
    product_type = db.query(models.ProductType).filter(
        models.ProductType.product_type_id == 'tcg_card'
    ).first()
    
    if not product_type:
        product_type = models.ProductType(
            product_type_id='tcg_card',
            product_type_name='Trading Card Game Card'
        )
        db.add(product_type)
        db.commit()
        print("✓ Added product type: tcg_card")
    else:
        print("✓ Product type already exists")
    
    # Add FFTCG sport
    sport = db.query(models.Sport).filter(
        models.Sport.sport_id == 'fftcg'
    ).first()
    
    if not sport:
        sport = models.Sport(
            sport_id='fftcg',
            sport_name='Final Fantasy Trading Card Game'
        )
        db.add(sport)
        db.commit()
        print("✓ Added sport: fftcg")
    else:
        print("✓ Sport already exists")
    
    # Check if Square Enix brand exists (by name, not ID)
    brand = db.query(models.Brand).filter(
        models.Brand.brand_name == 'Square Enix'
    ).first()
    
    if brand:
        print(f"✓ Brand already exists with ID: {brand.brand_id}")
    else:
        # Try to add with our ID
        brand = models.Brand(
            brand_id='square_enix',
            brand_name='Square Enix'
        )
        db.add(brand)
        db.commit()
        print("✓ Added brand: square_enix")
    
    print("\n✓ Database setup complete!")
    print("You can now upload fingerprints.")

if __name__ == "__main__":
    setup_fftcg_database()
