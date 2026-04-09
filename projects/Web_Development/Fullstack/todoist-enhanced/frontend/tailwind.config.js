/** @type {import('tailwindcss').Config} */
export default {
  content: [
    './index.html',
    './src/**/*.{js,ts,jsx,tsx}',
  ],
  darkMode: 'class',
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
      },
      colors: {
        todoist: {
          primary:   '#DB4035',
          secondary: '#FF9933',
          p1:        '#DB4035',
          p2:        '#FF9933',
          p3:        '#4073FF',
          p4:        '#808080',
          sidebar:   '#FAFAFA',
        },
      },
    },
  },
  plugins: [],
}
