class ApiService {
  async request(endpoint, options = {}) {
    const token = localStorage.getItem('token');
    const headers = {
      'Content-Type': 'application/json',
      ...(token && { Authorization: `Bearer ${token}` }),
      ...options.headers,
    };

    // Auth endpoints use /api prefix, others don't
    const url = endpoint.startsWith('/auth') ? `/api${endpoint}` : endpoint;

    const response = await fetch(url, {
      ...options,
      headers,
    });

    if (response.status === 401) {
      localStorage.removeItem('token');
      window.location.href = '/login';
      throw new Error('Unauthorized');
    }

    if (!response.ok) {
      const error = await response.json().catch(() => ({ detail: 'Request failed' }));
      throw new Error(error.detail || 'Request failed');
    }

    return response.json();
  }

  // Auth
  async login(email, password) {
    const response = await fetch('/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, remember_me: false }),
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({ detail: 'Login failed' }));
      throw new Error(error.detail || 'Login failed');
    }
    const data = await response.json();
    localStorage.setItem('token', data.access_token);
    return data;
  }

  async register(email, username, password, firstName, lastName) {
    return this.request('/auth/register', {
      method: 'POST',
      body: JSON.stringify({ email, username, password, first_name: firstName, last_name: lastName }),
    });
  }

  async getMe() {
    return this.request('/auth/me');
  }

  // Inventory
  async getInventory(params = {}) {
    const query = new URLSearchParams(params).toString();
    return this.request(`/inventory/?${query}`);
  }

  async updateInventory(id, data) {
    return this.request(`/inventory/${id}`, {
      method: 'PUT',
      body: JSON.stringify(data),
    });
  }

  // Shows
  async getShows() {
    return this.request('/shows/');
  }

  async getShowSummary(showId) {
    return this.request(`/shows/${showId}/`);
  }

  // Sales
  async getSales(params = {}) {
    const query = new URLSearchParams(params).toString();
    return this.request(`/sales/?${query}`);
  }

  // Expenses
  async getExpenses(params = {}) {
    const query = new URLSearchParams(params).toString();
    return this.request(`/expenses/?${query}`);
  }

  // Reports
  async getShowROI(year) {
    const query = year ? `?year=${year}` : '';
    return this.request(`/reports/show-roi${query}`);
  }

  async getFinancialSummary(year) {
    const query = year ? `?year=${year}` : '';
    return this.request(`/reports/financial-summary${query}`);
  }
}

export default new ApiService();
