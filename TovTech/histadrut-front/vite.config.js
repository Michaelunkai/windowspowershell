import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    host: "0.0.0.0",
    port: 5173,
    // Allow connections from your iPad
    cors: true,
    // Fix WebSocket HMR for network devices
    // hmr: {
    //   host: '192.168.1.4', // YOUR PC'S IP HERE
    //   protocol: 'ws',
    // },
    proxy: {
      "/api": {
        target: "http://192.168.1.4:5000",  // ה-IP של Flask
        rewrite: path => path.replace(/^\/api/, ""),
        changeOrigin: true,
        secure: false,
        // חשוב: תעביר עוגיות מהשרת
        configure: (proxy, _options) => {
          proxy.on("proxyReq", (proxyReq, req) => {
            if (req.headers.cookie) {
              proxyReq.setHeader("cookie", req.headers.cookie);
            }
          });
        }
      }
    }
  }
});
