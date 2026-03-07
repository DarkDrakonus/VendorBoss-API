import { useState, useEffect } from 'react';
import api from '../api';

export default function Dashboard() {
  const [user, setUser] = useState(null);
  const [shows, setShows] = useState([]);
  const [sales, setSales] = useState([]);
  const [expenses, setExpenses] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      const [userData, showsData, salesData, expensesData] = await Promise.all([
        api.getMe(),
        api.getShows(),
        api.getSales({ page_size: 100 }),
        api.getExpenses(),
      ]);
      setUser(userData);
      setShows(showsData);
      setSales(salesData.items || []);
      setExpenses(expensesData.items || []);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-screen">
        <div className="text-xl text-dark-text-secondary">Loading...</div>
      </div>
    );
  }

  const activeShow = shows.find(s => s.is_active);
  const totalSales = sales.reduce((sum, s) => sum + parseFloat(s.total_amount || 0), 0);
  const totalExpenses = expenses.reduce((sum, e) => sum + parseFloat(e.amount || 0), 0);
  const netProfit = totalSales - totalExpenses;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-dark-text">
          Welcome back, {user?.first_name || user?.username || 'Vendor'}!
        </h1>
        <p className="text-dark-text-secondary mt-1">Here's your business overview</p>
      </div>

      {activeShow && (
        <div className="bg-gradient-to-r from-primary to-primary-dark text-black rounded-xl p-6 shadow-lg">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm opacity-75 font-semibold">ACTIVE SHOW</p>
              <h2 className="text-2xl font-bold mt-1">{activeShow.show_name}</h2>
              <p className="text-sm opacity-75 mt-1">
                {new Date(activeShow.show_date).toLocaleDateString()} • {activeShow.location}
              </p>
            </div>
          </div>
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <StatCard
          title="Total Sales"
          value={`$${totalSales.toFixed(2)}`}
          subtitle={`${sales.length} transactions`}
          color="green"
        />
        <StatCard
          title="Total Expenses"
          value={`$${totalExpenses.toFixed(2)}`}
          subtitle={`${expenses.length} expenses`}
          color="orange"
        />
        <StatCard
          title="Net Profit"
          value={`$${netProfit.toFixed(2)}`}
          subtitle={netProfit >= 0 ? 'Profitable' : 'Loss'}
          color={netProfit >= 0 ? 'purple' : 'red'}
        />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="bg-dark-surface rounded-xl shadow-lg p-6">
          <h3 className="text-lg font-semibold mb-4 text-dark-text">Recent Shows</h3>
          {shows.length === 0 ? (
            <p className="text-dark-text-secondary">No shows yet</p>
          ) : (
            <div className="space-y-3">
              {shows.slice(0, 5).map(show => (
                <div key={show.show_id} className="flex justify-between items-center">
                  <div>
                    <p className="font-medium text-dark-text">{show.show_name}</p>
                    <p className="text-sm text-dark-text-secondary">
                      {new Date(show.show_date).toLocaleDateString()}
                    </p>
                  </div>
                  {show.is_active && (
                    <span className="px-2 py-1 bg-primary text-black text-xs rounded-full font-semibold">
                      Active
                    </span>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="bg-dark-surface rounded-xl shadow-lg p-6">
          <h3 className="text-lg font-semibold mb-4 text-dark-text">Recent Sales</h3>
          {sales.length === 0 ? (
            <p className="text-dark-text-secondary">No sales yet</p>
          ) : (
            <div className="space-y-3">
              {sales.slice(0, 5).map(sale => (
                <div key={sale.transaction_id} className="flex justify-between items-center">
                  <div>
                  <p className="font-medium text-dark-text">${parseFloat(sale.total_amount).toFixed(2)}</p>
                    <p className="text-sm text-dark-text-secondary">
                      {new Date(sale.transaction_date).toLocaleDateString()}
                    </p>
                  </div>
                  {sale.show_name && (
                    <span className="text-xs text-dark-text-secondary">{sale.show_name}</span>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function StatCard({ title, value, subtitle, color }) {
  const colors = {
    green: 'text-success',
    orange: 'text-warning',
    purple: 'text-primary',
    red: 'text-danger',
  };

  return (
    <div className="bg-dark-surface rounded-xl shadow-lg p-6">
      <p className="text-sm text-dark-text-secondary mb-2">{title}</p>
      <p className={`text-3xl font-bold ${colors[color]}`}>{value}</p>
      <p className="text-sm text-dark-text-secondary mt-2">{subtitle}</p>
    </div>
  );
}
