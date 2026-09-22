import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    proxy: {
      '/youtubei': {
        target: 'https://www.youtube.com',
        changeOrigin: true,
        headers: {
          'Origin': 'https://www.youtube.com',
          'Referer': 'https://www.youtube.com/',
        }
      },
      '/api': {
        target: 'https://www.youtube.com',
        changeOrigin: true,
        headers: {
          'Origin': 'https://www.youtube.com',
          'Referer': 'https://www.youtube.com/',
        }
      }
    }
  }
})
