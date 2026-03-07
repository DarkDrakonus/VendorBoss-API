import { useState, useEffect } from 'react';
import api from '../api';

export default function Inventory() {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [selectedItem, setSelectedItem] = useState(null);
  const [editForm, setEditForm] = useState({});

  useEffect(() => {
    loadInventory();
  }, []);

  const loadInventory = async () => {
    try {
      const data = await api.getInventory({ page_size: 100 });
      setItems(data.items || []);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleEdit = (item) => {
    setSelectedItem(item);
    setEditForm({
      quantity: item.quantity || 0,
      asking_price: item.asking_price || 0,
      condition: item.condition || 'NM',
      purchase_price: item.purchase_price || 0,
      current_market_price: item.current_market_price || 0,
      minimum_price: item.minimum_price || 0,
      storage_location: item.storage_location || '',
      box_number: item.box_number || '',
      row_number: item.row_number || '',
      notes: item.notes || '',
      for_sale: item.for_sale ?? true,
      featured: item.featured ?? false,
      // Card detail fields
      finish: item.finish || 'normal',
      language: item.language || 'English',
      graded: item.graded || false,
      grading_company: item.grading_company || '',
      grade: item.grade || ''
    });
  };

  const handleSave = async () => {
    try {
      // Only send inventory table fields, not card detail fields
      const inventoryData = {
        quantity: editForm.quantity,
        asking_price: editForm.asking_price,
        condition: editForm.condition,
        purchase_price: editForm.purchase_price,
        current_market_price: editForm.current_market_price,
        minimum_price: editForm.minimum_price,
        storage_location: editForm.storage_location,
        box_number: editForm.box_number,
        row_number: editForm.row_number,
        notes: editForm.notes,
        for_sale: editForm.for_sale,
        featured: editForm.featured
      };
      const updated = await api.updateInventory(selectedItem.inventory_id, inventoryData);
      // Update the item in the list with the response data
      setItems(items.map(item => 
        item.inventory_id === updated.inventory_id ? updated : item
      ));
      setSelectedItem(null);
    } catch (err) {
      alert(err.message);
    }
  };

  const filtered = items.filter(item =>
    (item.card_name || item.player || '').toLowerCase().includes(search.toLowerCase())
  );

  if (loading) {
    return <div className="text-center text-dark-text-secondary">Loading...</div>;
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-3xl font-bold text-dark-text">Inventory</h1>
        <button className="bg-primary hover:bg-primary-dark text-white px-4 py-2 rounded-lg transition">
          + Add Item
        </button>
      </div>

      <input
        type="text"
        placeholder="Search inventory..."
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        className="w-full px-4 py-3 bg-dark-surface border border-dark-elevated rounded-lg text-dark-text placeholder-dark-text-secondary focus:ring-2 focus:ring-primary focus:border-transparent"
      />

      {filtered.length === 0 ? (
        <div className="bg-dark-surface rounded-xl shadow-lg p-12 text-center">
          <p className="text-dark-text-secondary">No inventory items found</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {filtered.map(item => (
            <div 
              key={item.inventory_id} 
              onClick={() => handleEdit(item)}
              className="bg-dark-surface rounded-xl shadow-lg overflow-hidden hover:shadow-xl transition cursor-pointer"
            >
              {item.image_url && (
                <img 
                  src={item.image_url} 
                  alt={item.card_name || item.player}
                  className="w-full h-48 object-contain bg-dark-elevated"
                  onError={(e) => e.target.style.display = 'none'}
                />
              )}
              <div className="p-4">
                <div className="flex justify-between items-start mb-2">
                  <h3 className="font-semibold text-dark-text">{item.card_name || item.player || 'Unknown'}</h3>
                  <div className="flex gap-1">
                    <span className="text-xs px-2 py-1 bg-dark-elevated text-dark-text-secondary rounded">
                      {item.condition || 'NM'}
                    </span>
                    {(item.variant_name || item.is_foil) && (
                      <span className="text-xs px-2 py-1 bg-primary bg-opacity-20 text-primary rounded">
                        {item.variant_name || 'Foil'}
                      </span>
                    )}
                  </div>
                </div>
                {item.set_name && (
                  <p className="text-sm text-dark-text-secondary mb-2">{item.set_name}</p>
                )}
                <div className="flex justify-between items-center mt-3 pt-3 border-t border-dark-elevated">
                  <div>
                    <p className="text-xs text-dark-text-secondary">Qty</p>
                    <p className="font-semibold text-dark-text">{item.quantity || 0}</p>
                  </div>
                  <div className="text-right">
                    <p className="text-xs text-dark-text-secondary">Price</p>
                    <p className="font-semibold text-success">
                      ${parseFloat(item.asking_price || 0).toFixed(2)}
                    </p>
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {selectedItem && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50" onClick={() => setSelectedItem(null)}>
          <div className="bg-dark-surface rounded-xl p-6 max-w-2xl w-full max-h-[90vh] overflow-y-auto" onClick={(e) => e.stopPropagation()}>
            <h2 className="text-xl font-bold text-dark-text mb-4">Edit {selectedItem.card_name || selectedItem.player}</h2>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm text-dark-text-secondary mb-1">Quantity</label>
                <input
                  type="number"
                  value={editForm.quantity}
                  onChange={(e) => setEditForm({...editForm, quantity: parseInt(e.target.value) || 0})}
                  className="w-full px-3 py-2 bg-dark-elevated border border-dark-elevated rounded-lg text-dark-text"
                />
              </div>
              <div>
                <label className="block text-sm text-dark-text-secondary mb-1">Condition</label>
                <select
                  value={editForm.condition}
                  onChange={(e) => setEditForm({...editForm, condition: e.target.value})}
                  className="w-full px-3 py-2 bg-dark-elevated border border-dark-elevated rounded-lg text-dark-text"
                >
                  <option value="NM">Near Mint</option>
                  <option value="LP">Lightly Played</option>
                  <option value="MP">Moderately Played</option>
                  <option value="HP">Heavily Played</option>
                  <option value="DMG">Damaged</option>
                </select>
              </div>
              <div>
                <label className="block text-sm text-dark-text-secondary mb-1">Finish/Variant</label>
                <select
                  value={editForm.finish}
                  onChange={(e) => setEditForm({...editForm, finish: e.target.value})}
                  className="w-full px-3 py-2 bg-dark-elevated border border-dark-elevated rounded-lg text-dark-text"
                >
                  <option value="normal">Normal</option>
                  <option value="foil">Foil</option>
                  <option value="holo">Holo</option>
                  <option value="reverse_holo">Reverse Holo</option>
                  <option value="full_art">Full Art</option>
                  <option value="alternate_art">Alternate Art</option>
                </select>
              </div>
              <div>
                <label className="block text-sm text-dark-text-secondary mb-1">Language</label>
                <select
                  value={editForm.language}
                  onChange={(e) => setEditForm({...editForm, language: e.target.value})}
                  className="w-full px-3 py-2 bg-dark-elevated border border-dark-elevated rounded-lg text-dark-text"
                >
                  <option value="English">English</option>
                  <option value="Japanese">Japanese</option>
                  <option value="Spanish">Spanish</option>
                  <option value="French">French</option>
                  <option value="German">German</option>
                  <option value="Italian">Italian</option>
                  <option value="Korean">Korean</option>
                  <option value="Chinese">Chinese</option>
                </select>
              </div>
              <div>
                <label className="block text-sm text-dark-text-secondary mb-1">Asking Price</label>
                <input
                  type="number"
                  step="0.01"
                  value={editForm.asking_price}
                  onChange={(e) => setEditForm({...editForm, asking_price: parseFloat(e.target.value) || 0})}
                  className="w-full px-3 py-2 bg-dark-elevated border border-dark-elevated rounded-lg text-dark-text"
                />
              </div>
              <div>
                <label className="block text-sm text-dark-text-secondary mb-1">Purchase Price</label>
                <input
                  type="number"
                  step="0.01"
                  value={editForm.purchase_price}
                  onChange={(e) => setEditForm({...editForm, purchase_price: parseFloat(e.target.value) || 0})}
                  className="w-full px-3 py-2 bg-dark-elevated border border-dark-elevated rounded-lg text-dark-text"
                />
              </div>
              <div>
                <label className="block text-sm text-dark-text-secondary mb-1">Market Price</label>
                <input
                  type="number"
                  step="0.01"
                  value={editForm.current_market_price}
                  onChange={(e) => setEditForm({...editForm, current_market_price: parseFloat(e.target.value) || 0})}
                  className="w-full px-3 py-2 bg-dark-elevated border border-dark-elevated rounded-lg text-dark-text"
                />
              </div>
              <div>
                <label className="block text-sm text-dark-text-secondary mb-1">Minimum Price</label>
                <input
                  type="number"
                  step="0.01"
                  value={editForm.minimum_price}
                  onChange={(e) => setEditForm({...editForm, minimum_price: parseFloat(e.target.value) || 0})}
                  className="w-full px-3 py-2 bg-dark-elevated border border-dark-elevated rounded-lg text-dark-text"
                />
              </div>
              <div>
                <label className="block text-sm text-dark-text-secondary mb-1">Storage Location</label>
                <input
                  type="text"
                  value={editForm.storage_location}
                  onChange={(e) => setEditForm({...editForm, storage_location: e.target.value})}
                  className="w-full px-3 py-2 bg-dark-elevated border border-dark-elevated rounded-lg text-dark-text"
                />
              </div>
              <div>
                <label className="block text-sm text-dark-text-secondary mb-1">Box Number</label>
                <input
                  type="text"
                  value={editForm.box_number}
                  onChange={(e) => setEditForm({...editForm, box_number: e.target.value})}
                  className="w-full px-3 py-2 bg-dark-elevated border border-dark-elevated rounded-lg text-dark-text"
                />
              </div>
              <div>
                <label className="block text-sm text-dark-text-secondary mb-1">Row Number</label>
                <input
                  type="text"
                  value={editForm.row_number}
                  onChange={(e) => setEditForm({...editForm, row_number: e.target.value})}
                  className="w-full px-3 py-2 bg-dark-elevated border border-dark-elevated rounded-lg text-dark-text"
                />
              </div>
              <div className="col-span-2">
                <label className="flex items-center gap-2 text-dark-text cursor-pointer mb-3">
                  <input
                    type="checkbox"
                    checked={editForm.graded}
                    onChange={(e) => setEditForm({...editForm, graded: e.target.checked})}
                    className="w-4 h-4"
                  />
                  <span className="text-sm font-semibold">Graded Card</span>
                </label>
                {editForm.graded && (
                  <div className="grid grid-cols-2 gap-4 pl-6">
                    <div>
                      <label className="block text-sm text-dark-text-secondary mb-1">Grading Company</label>
                      <select
                        value={editForm.grading_company}
                        onChange={(e) => setEditForm({...editForm, grading_company: e.target.value})}
                        className="w-full px-3 py-2 bg-dark-elevated border border-dark-elevated rounded-lg text-dark-text"
                      >
                        <option value="">Select Company</option>
                        <option value="PSA">PSA</option>
                        <option value="BGS">BGS/Beckett</option>
                        <option value="CGC">CGC</option>
                        <option value="SGC">SGC</option>
                      </select>
                    </div>
                    <div>
                      <label className="block text-sm text-dark-text-secondary mb-1">Grade</label>
                      <input
                        type="text"
                        value={editForm.grade}
                        onChange={(e) => setEditForm({...editForm, grade: e.target.value})}
                        placeholder="e.g. 10, 9.5"
                        className="w-full px-3 py-2 bg-dark-elevated border border-dark-elevated rounded-lg text-dark-text"
                      />
                    </div>
                  </div>
                )}
              </div>
              <div className="col-span-2">
                <label className="block text-sm text-dark-text-secondary mb-1">Notes</label>
                <textarea
                  value={editForm.notes}
                  onChange={(e) => setEditForm({...editForm, notes: e.target.value})}
                  rows="3"
                  className="w-full px-3 py-2 bg-dark-elevated border border-dark-elevated rounded-lg text-dark-text"
                />
              </div>
              <div className="flex items-center gap-4">
                <label className="flex items-center gap-2 text-dark-text cursor-pointer">
                  <input
                    type="checkbox"
                    checked={editForm.for_sale}
                    onChange={(e) => setEditForm({...editForm, for_sale: e.target.checked})}
                    className="w-4 h-4"
                  />
                  <span className="text-sm">For Sale</span>
                </label>
                <label className="flex items-center gap-2 text-dark-text cursor-pointer">
                  <input
                    type="checkbox"
                    checked={editForm.featured}
                    onChange={(e) => setEditForm({...editForm, featured: e.target.checked})}
                    className="w-4 h-4"
                  />
                  <span className="text-sm">Featured</span>
                </label>
              </div>
            </div>
            <div className="flex gap-3 mt-6">
              <button
                onClick={() => setSelectedItem(null)}
                className="flex-1 px-4 py-2 bg-dark-elevated text-dark-text rounded-lg hover:bg-opacity-80 transition"
              >
                Cancel
              </button>
              <button
                onClick={handleSave}
                className="flex-1 px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary-dark transition"
              >
                Save
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
