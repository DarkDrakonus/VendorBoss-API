/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,jsx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: '#00C896',
        'primary-dark': '#00A07A',
        accent: '#00C896',
        success: '#2ECC71',
        danger: '#E74C3C',
        warning: '#F39C12',
        info: '#3498DB',
        dark: {
          bg: '#0F1117',
          surface: '#1A1D27',
          elevated: '#22263A',
          appbar: '#13151F',
          text: '#EEF0F8',
          'text-secondary': '#8B91B0',
          'text-light': '#4A5070',
          divider: '#252840',
        },
      },
    },
  },
  plugins: [],
}
