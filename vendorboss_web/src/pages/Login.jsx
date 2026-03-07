import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../api';

export default function Login() {
  const [isLogin, setIsLogin] = useState(true);
  const [email, setEmail] = useState('');
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      if (isLogin) {
        await api.login(email, password);
        navigate('/');
      } else {
        await api.register(email, username, password, firstName, lastName);
        await api.login(email, password);
        navigate('/');
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-dark-bg via-dark-surface to-dark-elevated">
      <div className="bg-dark-surface rounded-2xl shadow-2xl p-8 w-full max-w-md border border-dark-divider">
        <div className="text-center mb-8">
          <h1 className="text-3xl font-bold text-dark-text">VendorBoss</h1>
          <p className="text-dark-text-secondary mt-2">TCG Vendor Management</p>
        </div>

        <div className="flex gap-2 mb-6">
          <button
            onClick={() => setIsLogin(true)}
            style={isLogin ? { backgroundColor: '#00C896', color: '#000000' } : { backgroundColor: '#22263A', color: '#8B91B0' }}
            className="flex-1 py-2 rounded-lg font-semibold transition"
          >
            Login
          </button>
          <button
            onClick={() => setIsLogin(false)}
            style={!isLogin ? { backgroundColor: '#00C896', color: '#000000' } : { backgroundColor: '#22263A', color: '#8B91B0' }}
            className="flex-1 py-2 rounded-lg font-semibold transition"
          >
            Register
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          {!isLogin && (
            <>
              <input
                type="text"
                placeholder="First Name"
                value={firstName}
                onChange={(e) => setFirstName(e.target.value)}
                style={{ backgroundColor: '#22263A', borderColor: '#252840', color: '#EEF0F8' }}
                className="w-full px-4 py-3 border rounded-lg focus:ring-2 focus:ring-primary focus:border-transparent placeholder-gray-500"
                required
              />
              <input
                type="text"
                placeholder="Last Name"
                value={lastName}
                onChange={(e) => setLastName(e.target.value)}
                style={{ backgroundColor: '#22263A', borderColor: '#252840', color: '#EEF0F8' }}
                className="w-full px-4 py-3 border rounded-lg focus:ring-2 focus:ring-primary focus:border-transparent placeholder-gray-500"
                required
              />
              <input
                type="text"
                placeholder="Username"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                style={{ backgroundColor: '#22263A', borderColor: '#252840', color: '#EEF0F8' }}
                className="w-full px-4 py-3 border rounded-lg focus:ring-2 focus:ring-primary focus:border-transparent placeholder-gray-500"
                required
              />
            </>
          )}
          <input
            type="email"
            placeholder="Email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            style={{ backgroundColor: '#22263A', borderColor: '#252840', color: '#EEF0F8' }}
            className="w-full px-4 py-3 border rounded-lg focus:ring-2 focus:ring-primary focus:border-transparent placeholder-gray-500"
            required
          />
          <input
            type="password"
            placeholder="Password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            style={{ backgroundColor: '#22263A', borderColor: '#252840', color: '#EEF0F8' }}
            className="w-full px-4 py-3 border rounded-lg focus:ring-2 focus:ring-primary focus:border-transparent placeholder-gray-500"
            required
          />

          {error && (
            <div className="bg-danger bg-opacity-10 text-danger px-4 py-3 rounded-lg text-sm border border-danger border-opacity-20">
              {error}
            </div>
          )}

          <button
            type="submit"
            disabled={loading}
            style={{ backgroundColor: loading ? '#00A07A' : '#00C896' }}
            className="w-full hover:bg-primary-dark text-black font-semibold py-3 rounded-lg transition disabled:opacity-50"
          >
            {loading ? 'Loading...' : isLogin ? 'Login' : 'Create Account'}
          </button>
        </form>
      </div>
    </div>
  );
}
