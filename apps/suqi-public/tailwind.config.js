/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        // TBWA Brand Colors
        'tbwa-orange': '#FF6B35',
        'tbwa-yellow': '#F7931E',
        'tbwa-blue': '#1E90FF',
        'tbwa-purple': '#9370DB',

        // Extended color palette for charts
        'chart-1': '#FF6B35',
        'chart-2': '#F7931E',
        'chart-3': '#FFD700',
        'chart-4': '#32CD32',
        'chart-5': '#1E90FF',
        'chart-6': '#9370DB',
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
      },
      animation: {
        'fade-in': 'fadeIn 0.3s ease-out',
        'slide-in': 'slideIn 0.3s ease-out',
        'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0', transform: 'translateY(10px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
        slideIn: {
          '0%': { transform: 'translateX(-100%)' },
          '100%': { transform: 'translateX(0)' },
        },
      },
      spacing: {
        '18': '4.5rem',
        '88': '22rem',
      },
      maxWidth: {
        '8xl': '88rem',
        '9xl': '96rem',
      },
      zIndex: {
        '60': '60',
        '70': '70',
        '80': '80',
        '90': '90',
        '100': '100',
      },
      blur: {
        xs: '2px',
      },
      backdropBlur: {
        xs: '2px',
      },
    },
  },
  plugins: [
    // Add any additional Tailwind plugins here
    function({ addUtilities }) {
      const newUtilities = {
        '.text-shadow': {
          textShadow: '1px 1px 2px rgba(0, 0, 0, 0.1)',
        },
        '.text-shadow-md': {
          textShadow: '2px 2px 4px rgba(0, 0, 0, 0.1)',
        },
        '.text-shadow-lg': {
          textShadow: '4px 4px 8px rgba(0, 0, 0, 0.1)',
        },
        '.scrollbar-hide': {
          /* Hide scrollbar for Chrome, Safari and Opera */
          '&::-webkit-scrollbar': {
            display: 'none',
          },
          /* Hide scrollbar for IE, Edge and Firefox */
          '-ms-overflow-style': 'none',
          'scrollbar-width': 'none',
        },
        '.gradient-mask-b-0': {
          '-webkit-mask-image': 'linear-gradient(to bottom, black, transparent)',
          'mask-image': 'linear-gradient(to bottom, black, transparent)',
        },
        '.gradient-mask-r-0': {
          '-webkit-mask-image': 'linear-gradient(to right, black, transparent)',
          'mask-image': 'linear-gradient(to right, black, transparent)',
        },
      }
      addUtilities(newUtilities)
    }
  ],
}