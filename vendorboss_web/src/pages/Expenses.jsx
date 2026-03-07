import { useState, useEffect } from 'react';
import api from '../api';

export default function Expenses() {
  const [expenses, setExpenses] = useState([]);
  const [shows, setShows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedShow, setSelectedShow] = useState('all');

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      const [expensesData, showsData] = await Promise.all([
        api.getExpenses(),
        api.getShows(),
      ]);
      setExpenses(expensesData.items || []);
      setShows(showsData);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const filtered = selectedShow === 'all'
    ? expenses
    : expenses.filter(e => e.show_id === selectedShow);

  const total = filtered.reduce((sum, e) => sum + parseFloat(e.amount || 0), 0);

  if (loading) {
    return <div className="text-center text-dark-text-secondary">Loading...</div>;
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-3xl font-bold text-dark-text">Expenses</h1>
        <div className="text-right">
          <p className="text-sm text-dark-text-secondary">Total Expenses</p>
          <p className="text-2xl font-bold text-warning">${total.toFixed(2)}</p>
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
          <p className="text-dark-text-secondary">No expenses found</p>
        </div>
      ) : (
        <div className="space-y-3">
          {filtered.map(expense => (
            <div key={expense.expense_id} className="bg-dark-surface rounded-xl shadow-lg p-6">
              <div className="flex justify-between items-start">
                <div className="flex-1">
                  <div className="flex items-center gap-3 mb-2">
                    <p className="text-2xl font-bold text-warning">
                      ${parseFloat(expense.amount).toFixed(2)}
                    </p>
                    <span className="px-2 py-1 bg-dark-elevated text-dark-text-secondary text-xs rounded-full">
                      {expense.expense_type}
                    </span>
                  </div>
                  <p className="text-lg font-semibold text-dark-text">{expense.description}</p>
                  <p className="text-dark-text-secondary mt-1">
                    {new Date(expense.expense_date).toLocaleDateString()}
                  </p>
                  {expense.payment_method && (
                    <p className="text-sm text-dark-text-secondary">
                      Payment: {expense.payment_method}
                    </p>
                  )}
                </div>
              </div>
              {expense.notes && (
                <p className="mt-3 pt-3 border-t border-dark-elevated text-sm text-dark-text-secondary">
                  {expense.notes}
                </p>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
