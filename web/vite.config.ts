import { defineConfig } from "vite";

export default defineConfig({
  base: "./",
  build: {
    target: "esnext",
    outDir: "dist",
    assetsInlineLimit: 4096,
  },
  server: {
    port: 5180,
    host: "0.0.0.0",
  },
});
