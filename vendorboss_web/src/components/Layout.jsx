import { Link, useNavigate, useLocation } from 'react-router-dom';

export default function Layout({ children }) {
  const navigate = useNavigate();
  const location = useLocation();

  const handleLogout = () => {
    localStorage.removeItem('token');
    navigate('/login');
  };

  const isActive = (path) => location.pathname === path;

  return (
    <div className="min-h-screen bg-dark-bg">
      <nav className="bg-dark-appbar border-b border-dark-divider">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between h-16">
            <div className="flex items-center space-x-8">
              <Link to="/" className="text-2xl font-bold text-primary">
                VendorBoss
              </Link>
              <div className="hidden md:flex space-x-4">
                <NavLink to="/" active={isActive('/')}>Dashboard</NavLink>
                <NavLink to="/inventory" active={isActive('/inventory')}>Inventory</NavLink>
                <NavLink to="/shows" active={isActive('/shows')}>Shows</NavLink>
                <NavLink to="/sales" active={isActive('/sales')}>Sales</NavLink>
                <NavLink to="/expenses" active={isActive('/expenses')}>Expenses</NavLink>
                <NavLink to="/reports" active={isActive('/reports')}>Reports</NavLink>
              </div>
            </div>
            <div className="flex items-center">
              <button
                onClick={handleLogout}
                className="text-dark-text-secondary hover:text-dark-text px-4 py-2 rounded-lg hover:bg-dark-elevated transition"
              >
                Logout
              </button>
            </div>
          </div>
        </div>
      </nav>

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {children}
      </main>
    </div>
  );
}

function NavLink({ to, active, children }) {
  return (
    <Link
      to={to}
      className={`px-3 py-2 rounded-lg font-medium transition ${
        active
          ? 'bg-primary text-black'
          : 'text-dark-text-secondary hover:text-dark-text hover:bg-dark-elevated'
      }`}
    >
      {children}
    </Link>
  );
}
