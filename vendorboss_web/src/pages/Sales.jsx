import { useState, useEffect } from 'react';
import api from '../api';

export default function Sales() {
  const [sales, setSales] = useState([]);
  const [shows, setShows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedShow, setSelectedShow] = useState('all');

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      const [salesData, showsData] = await Promise.all([
        api.getSales({ page_size: 200 }),
        api.getShows(),
      ]);
      setSales(salesData.items || []);
      setShows(showsData);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const filtered = selectedShow === 'all' 
    ? sales 
    : sales.filter(s => s.show_name === shows.find(sh => sh.show_id === selectedShow)?.show_name);

  const total = filtered.reduce((sum, s) => sum + parseFloat(s.total_amount || 0), 0);

  if (loading) {
    return <div className="text-center text-dark-text-secondary">Loading...</div>;
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-3xl font-bold text-dark-text">Sales</h1>
        <div className="text-right">
          <p className="text-sm text-dark-text-secondary">Total Revenue</p>
          <p className="text-2xl font-bold text-success">${total.toFixed(2)}</p>
        </div>
      </div>

      <select
        value={selectedShow}
        onChange={(e) => setSelectedShow(e.target.value)}
        className="w-full px-4 py-3 bg-dark-surface border border-dark-elevated rounded-lg text-dark-text focus:ring-2 focus:ring-primary"
      >
        <option value="all">All Shows</option>
        {shows.map(show => (
          <option key={show.show_id} value={show.show_id}>{show.show_name}</option>
        ))}
      </select>

      {filtered.length === 0 ? (
        <div className="bg-dark-surface rounded-xl shadow-lg p-12 text-center">
          <p className="text-dark-text-secondary">No sales found</p>
        </div>
      ) : (
        <div className="space-y-3">
          {filtered.map(sale => (
            <div key={sale.transaction_id} className="bg-dark-surface rounded-xl shadow-lg p-6">
              <div className="flex justify-between items-start">
                <div className="flex-1">
                  <div className="flex items-center gap-3 mb-2">
                    <p className="text-2xl font-bold text-success">
                      ${parseFloat(sale.total_amount).toFixed(2)}
                    </p>
                    {sale.show_name && (
                      <span className="px-2 py-1 bg-primary text-black text-xs rounded-full font-semibold">
                        {sale.show_name}
                      </span>
                    )}
                  </div>
                  <p className="text-dark-text-secondary">
                    {new Date(sale.transaction_date).toLocaleString()}
                  </p>
                  {sale.customer_name && (
                    <p className="text-sm text-dark-text-secondary mt-1">
                      Customer: {sale.customer_name}
                    </p>
                  )}
                  {sale.payment_method && (
                    <p className="text-sm text-dark-text-secondary">
                      Payment: {sale.payment_method}
                    </p>
                  )}
                </div>
                <div className="text-right">
                  <p className="text-xs text-dark-text-secondary">Qty</p>
                  <p className="text-lg font-semibold text-dark-text">{sale.quantity}</p>
                </div>
              </div>
              {sale.notes && (
                <p className="mt-3 pt-3 border-t border-dark-elevated text-sm text-dark-text-secondary">
                  {sale.notes}
                </p>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
