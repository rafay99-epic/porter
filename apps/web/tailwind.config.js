/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        // Paper & ink — a warm-neutral editorial canvas, not bright white.
        paper: {
          DEFAULT: '#f4f2ec',
          deep: '#ece8df', // wells / fills
          raised: '#fbfaf6', // raised surfaces
        },
        card: '#ffffff',
        ink: {
          DEFAULT: '#15171c',
          2: '#52565f', // secondary text
          3: '#888d96', // tertiary text
          line: 'rgba(20,22,28,0.10)',
        },
        // The single saturated accent — Porter's app-icon blue.
        blue: {
          DEFAULT: '#1f6ef0',
          deep: '#1a5cdb',
          soft: '#e7effe',
          50: '#eef5ff',
          100: '#d9e8ff',
          200: '#bcd6ff',
          500: '#4089fa',
          600: '#1f6ef0',
          700: '#1a5cdb',
        },
        // One bold dark chapter (the engineering story).
        night: {
          DEFAULT: '#0d0e12',
          raised: '#16181e',
          line: 'rgba(255,255,255,0.10)',
          ink: '#e9e7e1',
          2: '#9aa0ab',
        },
        // Functional status signals (statusColor in the app).
        ok: '#34c759',
        warn: '#ff9f0a',
        bad: '#ff453a',
      },
      fontFamily: {
        display: ['"Bricolage Grotesque Variable"', 'Georgia', 'serif'],
        sans: [
          '"Geist Variable"', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI',
          'Roboto', 'Helvetica Neue', 'Arial', 'sans-serif',
        ],
        mono: [
          '"Geist Mono Variable"', '"SF Mono"', 'SFMono-Regular', 'ui-monospace',
          'Menlo', 'monospace',
        ],
        // The native windows specifically want the macOS system font.
        system: ['-apple-system', 'BlinkMacSystemFont', '"SF Pro Text"', 'Inter', 'sans-serif'],
      },
      letterSpacing: {
        tightest: '-0.04em',
        tighter: '-0.03em',
      },
      boxShadow: {
        window: '0 1px 1px rgba(20,22,28,0.04), 0 18px 40px -12px rgba(20,22,28,0.22), 0 42px 90px -40px rgba(20,22,28,0.30)',
        popover: '0 1px 0 rgba(255,255,255,0.6) inset, 0 10px 20px -8px rgba(20,22,28,0.20), 0 30px 60px -24px rgba(20,22,28,0.34)',
        lift: '0 1px 2px rgba(20,22,28,0.05), 0 10px 30px -14px rgba(20,22,28,0.20)',
        tag: '0 1px 2px rgba(20,22,28,0.06), 0 8px 18px -10px rgba(20,22,28,0.18)',
        bluey: '0 10px 40px -12px rgba(31,110,240,0.45)',
      },
      transitionTimingFunction: {
        spring: 'cubic-bezier(0.16, 1, 0.3, 1)',
      },
      keyframes: {
        spin360: { to: { transform: 'rotate(360deg)' } },
        blink: { '0%,100%': { opacity: '1' }, '50%': { opacity: '0.3' } },
      },
      animation: {
        'spin-slow': 'spin360 2.4s linear infinite',
        blink: 'blink 1.4s ease-in-out infinite',
      },
    },
  },
  plugins: [],
}
