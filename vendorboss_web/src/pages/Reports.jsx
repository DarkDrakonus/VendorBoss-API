import { useState, useEffect } from 'react';
import { BarChart, Bar, LineChart, Line, PieChart, Pie, Cell, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import api from '../api';

const COLORS = ['#00C896', '#2ECC71', '#F39C12', '#E74C3C', '#3498DB'];

export default function Reports() {
  const [showROI, setShowROI] = useState([]);
  const [financial, setFinancial] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadReports();
  }, []);

  const loadReports = async () => {
    try {
      const [roiData, financialData] = await Promise.all([
        api.getShowROI(),
        api.getFinancialSummary(),
      ]);
      setShowROI(roiData.shows || []);
      setFinancial(financialData);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return <div className="text-center text-dark-text-secondary">Loading...</div>;
  }

  const showChartData = showROI.map(show => ({
    name: show.show_name?.substring(0, 15) || 'Unknown',
    sales: parseFloat(show.total_sales || 0),
    expenses: parseFloat(show.total_expenses || 0),
    profit: parseFloat(show.net_profit || 0),
  }));

  const monthlyData = financial?.monthly_breakdown?.map(m => ({
    month: m.month,
    sales: parseFloat(m.sales || 0),
    expenses: parseFloat(m.expenses || 0),
    profit: parseFloat(m.profit || 0),
  })) || [];

  const categoryData = financial?.expense_by_category?.map((cat, idx) => ({
    name: cat.category,
    value: parseFloat(cat.total || 0),
    color: COLORS[idx % COLORS.length],
  })) || [];

  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-bold text-dark-text">Reports & Analytics</h1>

      {financial && (
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <StatCard title="Total Sales" value={`$${parseFloat(financial.total_sales || 0).toFixed(2)}`} color="green" />
          <StatCard title="Total Expenses" value={`$${parseFloat(financial.total_expenses || 0).toFixed(2)}`} color="orange" />
          <StatCard title="Net Profit" value={`$${parseFloat(financial.net_profit || 0).toFixed(2)}`} color="purple" />
          <StatCard title="Avg Show Profit" value={`$${parseFloat(financial.avg_show_profit || 0).toFixed(2)}`} color="blue" />
        </div>
      )}

      {showChartData.length > 0 && (
        <div className="bg-dark-surface rounded-xl shadow-lg p-6">
          <h2 className="text-xl font-bold text-dark-text mb-4">Show Performance</h2>
          <ResponsiveContainer width="100%" height={300}>
            <BarChart data={showChartData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#252840" />
              <XAxis dataKey="name" stroke="#8B91B0" />
              <YAxis stroke="#8B91B0" />
              <Tooltip 
                contentStyle={{ backgroundColor: '#1A1D27', border: '1px solid #252840', borderRadius: '8px' }}
                labelStyle={{ color: '#EEF0F8' }}
              />
              <Legend />
              <Bar dataKey="sales" fill="#2ECC71" name="Sales" />
              <Bar dataKey="expenses" fill="#F39C12" name="Expenses" />
              <Bar dataKey="profit" fill="#00C896" name="Profit" />
            </BarChart>
          </ResponsiveContainer>
        </div>
      )}

      {monthlyData.length > 0 && (
        <div className="bg-dark-surface rounded-xl shadow-lg p-6">
          <h2 className="text-xl font-bold text-dark-text mb-4">Monthly Trends</h2>
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={monthlyData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#252840" />
              <XAxis dataKey="month" stroke="#8B91B0" />
              <YAxis stroke="#8B91B0" />
              <Tooltip 
                contentStyle={{ backgroundColor: '#1A1D27', border: '1px solid #252840', borderRadius: '8px' }}
                labelStyle={{ color: '#EEF0F8' }}
              />
              <Legend />
              <Line type="monotone" dataKey="sales" stroke="#2ECC71" strokeWidth={2} name="Sales" />
              <Line type="monotone" dataKey="expenses" stroke="#F39C12" strokeWidth={2} name="Expenses" />
              <Line type="monotone" dataKey="profit" stroke="#00C896" strokeWidth={2} name="Profit" />
            </LineChart>
          </ResponsiveContainer>
        </div>
      )}

      {categoryData.length > 0 && (
        <div className="bg-dark-surface rounded-xl shadow-lg p-6">
          <h2 className="text-xl font-bold text-dark-text mb-4">Expenses by Category</h2>
          <ResponsiveContainer width="100%" height={300}>
            <PieChart>
              <Pie
                data={categoryData}
                cx="50%"
                cy="50%"
                labelLine={false}
                label={({ name, percent }) => `${name}: ${(percent * 100).toFixed(0)}%`}
                outerRadius={100}
                fill="#8884d8"
                dataKey="value"
              >
                {categoryData.map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={entry.color} />
                ))}
              </Pie>
              <Tooltip 
                contentStyle={{ backgroundColor: '#1A1D27', border: '1px solid #252840', borderRadius: '8px' }}
              />
            </PieChart>
          </ResponsiveContainer>
        </div>
      )}
    </div>
  );
}

function StatCard({ title, value, color }) {
  const colors = {
    green: 'text-success',
    orange: 'text-warning',
    purple: 'text-primary',
    blue: 'text-info',
  };

  return (
    <div className="bg-dark-surface rounded-xl shadow-lg p-6">
      <p className="text-sm text-dark-text-secondary mb-2">{title}</p>
      <p className={`text-2xl font-bold ${colors[color]}`}>{value}</p>
    </div>
  );
}
