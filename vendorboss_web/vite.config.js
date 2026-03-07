import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
    proxy: {
      '/api': {
        target: 'http://192.168.1.37:8001',
        changeOrigin: true
      },
      '/inventory': {
        target: 'http://192.168.1.37:8001',
        changeOrigin: true
      },
      '/shows': {
        target: 'http://192.168.1.37:8001',
        changeOrigin: true
      },
      '/sales': {
        target: 'http://192.168.1.37:8001',
        changeOrigin: true
      },
      '/expenses': {
        target: 'http://192.168.1.37:8001',
        changeOrigin: true
      },
      '/reports': {
        target: 'http://192.168.1.37:8001',
        changeOrigin: true
      }
    }
  }
})
