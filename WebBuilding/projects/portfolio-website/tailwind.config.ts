import type { Config } from "tailwindcss";

const config: Config = {
  darkMode: "class",
  content: [
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        bg: {
          primary: "#0a0b14",
          card: "#0f1020",
          cardHover: "#141528",
        },
        accent: {
          purple: "#7c3aed",
          purpleLight: "#a855f7",
          green: "#10b981",
          blue: "#3b82f6",
        },
        border: "rgba(255,255,255,0.07)",
      },
      fontFamily: {
        sans: ["Inter", "sans-serif"],
      },
    },
  },
  plugins: [],
};

export default config;
