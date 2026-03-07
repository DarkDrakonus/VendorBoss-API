import { useState, useEffect } from 'react';
import api from '../api';

export default function Shows() {
  const [shows, setShows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);

  useEffect(() => {
    loadShows();
  }, []);

  const loadShows = async () => {
    try {
      const data = await api.getShows();
      setShows(data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const activeShows = shows.filter(s => s.is_active);
  const pastShows = shows.filter(s => !s.is_active).sort((a, b) => 
    new Date(b.show_date) - new Date(a.show_date)
  );

  if (loading) {
    return <div className="text-center text-dark-text-secondary">Loading...</div>;
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-3xl font-bold text-dark-text">Shows</h1>
        <button 
          onClick={() => setShowModal(true)}
          className="bg-primary hover:bg-primary-dark text-white px-4 py-2 rounded-lg transition"
        >
          + New Show
        </button>
      </div>

      {activeShows.length > 0 && (
        <div>
          <h2 className="text-lg font-semibold text-dark-text mb-3">Active Shows</h2>
          <div className="space-y-3">
            {activeShows.map(show => (
              <ShowCard key={show.show_id} show={show} isActive={true} onUpdate={loadShows} />
            ))}
          </div>
        </div>
      )}

      <div>
        <h2 className="text-lg font-semibold text-dark-text mb-3">Past Shows</h2>
        {pastShows.length === 0 ? (
          <div className="bg-dark-surface rounded-xl shadow-lg p-12 text-center">
            <p className="text-dark-text-secondary">No past shows yet</p>
          </div>
        ) : (
          <div className="space-y-3">
            {pastShows.map(show => (
              <ShowCard key={show.show_id} show={show} isActive={false} onUpdate={loadShows} />
            ))}
          </div>
        )}
      </div>

      {showModal && <CreateShowModal onClose={() => setShowModal(false)} onCreated={loadShows} />}
    </div>
  );
}

function ShowCard({ show, isActive, onUpdate }) {
  const [summary, setSummary] = useState(null);
  const [expanded, setExpanded] = useState(false);

  const loadSummary = async () => {
    if (!expanded) {
      try {
        const data = await api.getShowSummary(show.show_id);
        setSummary(data);
      } catch (err) {
        console.error(err);
      }
    }
    setExpanded(!expanded);
  };

  return (
    <div className="bg-dark-surface rounded-xl shadow-lg p-6">
      <div className="flex justify-between items-start">
        <div className="flex-1">
          <div className="flex items-center gap-3 mb-2">
            <h3 className="text-xl font-bold text-dark-text">{show.show_name}</h3>
            {isActive && (
              <span className="px-3 py-1 bg-primary text-black text-xs rounded-full font-semibold">
                ACTIVE
              </span>
            )}
          </div>
          <p className="text-dark-text-secondary">
            {new Date(show.show_date).toLocaleDateString('en-US', { 
              weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' 
            })}
          </p>
          {show.venue && (
            <p className="text-sm text-dark-text-secondary mt-1">
              {show.venue} {show.table_number && `• Table ${show.table_number}`} {show.location && `• ${show.location}`}
            </p>
          )}
        </div>
        <button
          onClick={loadSummary}
          className="text-primary hover:text-primary-dark transition"
        >
          {expanded ? '▼' : '▶'}
        </button>
      </div>

      {expanded && summary && (
        <div className="mt-4 pt-4 border-t border-dark-elevated grid grid-cols-4 gap-4">
          <div>
            <p className="text-xs text-dark-text-secondary">Sales</p>
            <p className="text-lg font-bold text-success">
              ${parseFloat(summary.total_sales || 0).toFixed(2)}
            </p>
          </div>
          <div>
            <p className="text-xs text-dark-text-secondary">Expenses</p>
            <p className="text-lg font-bold text-warning">
              ${parseFloat(summary.total_expenses || 0).toFixed(2)}
            </p>
          </div>
          <div>
            <p className="text-xs text-dark-text-secondary">Net</p>
            <p className={`text-lg font-bold ${summary.net_profit >= 0 ? 'text-primary' : 'text-danger'}`}>
              ${parseFloat(summary.net_profit || 0).toFixed(2)}
            </p>
          </div>
          <div>
            <p className="text-xs text-dark-text-secondary">Transactions</p>
            <p className="text-lg font-bold text-dark-text">{summary.transaction_count || 0}</p>
          </div>
        </div>
      )}
    </div>
  );
}

function CreateShowModal({ onClose, onCreated }) {
  const [formData, setFormData] = useState({
    show_name: '',
    show_date: new Date().toISOString().split('T')[0],
    location: '',
    venue: '',
    table_number: '',
    table_cost: '',
    notes: '',
  });
  const [saving, setSaving] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      await api.request('/shows', {
        method: 'POST',
        body: JSON.stringify(formData),
      });
      onCreated();
      onClose();
    } catch (err) {
      alert(err.message);
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center z-50">
      <div className="bg-dark-surface rounded-xl p-6 w-full max-w-md">
        <h2 className="text-2xl font-bold text-dark-text mb-4">Create New Show</h2>
        <form onSubmit={handleSubmit} className="space-y-4">
          <input
            type="text"
            placeholder="Show Name *"
            value={formData.show_name}
            onChange={(e) => setFormData({...formData, show_name: e.target.value})}
            className="w-full px-4 py-3 bg-dark-elevated border border-dark-elevated rounded-lg text-dark-text placeholder-dark-text-secondary focus:ring-2 focus:ring-primary"
            required
          />
          <input
            type="date"
            value={formData.show_date}
            onChange={(e) => setFormData({...formData, show_date: e.target.value})}
            className="w-full px-4 py-3 bg-dark-elevated border border-dark-elevated rounded-lg text-dark-text focus:ring-2 focus:ring-primary"
            required
          />
          <input
            type="text"
            placeholder="Venue"
            value={formData.venue}
            onChange={(e) => setFormData({...formData, venue: e.target.value})}
            className="w-full px-4 py-3 bg-dark-elevated border border-dark-elevated rounded-lg text-dark-text placeholder-dark-text-secondary focus:ring-2 focus:ring-primary"
          />
          <input
            type="text"
            placeholder="Location"
            value={formData.location}
            onChange={(e) => setFormData({...formData, location: e.target.value})}
            className="w-full px-4 py-3 bg-dark-elevated border border-dark-elevated rounded-lg text-dark-text placeholder-dark-text-secondary focus:ring-2 focus:ring-primary"
          />
          <div className="grid grid-cols-2 gap-4">
            <input
              type="text"
              placeholder="Table #"
              value={formData.table_number}
              onChange={(e) => setFormData({...formData, table_number: e.target.value})}
              className="w-full px-4 py-3 bg-dark-elevated border border-dark-elevated rounded-lg text-dark-text placeholder-dark-text-secondary focus:ring-2 focus:ring-primary"
            />
            <input
              type="number"
              step="0.01"
              placeholder="Table Cost"
              value={formData.table_cost}
              onChange={(e) => setFormData({...formData, table_cost: e.target.value})}
              className="w-full px-4 py-3 bg-dark-elevated border border-dark-elevated rounded-lg text-dark-text placeholder-dark-text-secondary focus:ring-2 focus:ring-primary"
            />
          </div>
          <div className="flex gap-3">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 px-4 py-3 bg-dark-elevated text-dark-text rounded-lg hover:bg-dark-bg transition"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={saving}
              className="flex-1 px-4 py-3 bg-primary hover:bg-primary-dark text-white rounded-lg transition disabled:opacity-50"
            >
              {saving ? 'Creating...' : 'Create Show'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
