/// <reference types="vitest" />

/**
What's going on with library mode?

Glad you asked, here's a quick rundown:

1. vite-plugin-ruby will automatically bring all the entrypoints like dashbord and widget as input to vite.
2. vite needs to be in library mode to build the SDK as a single file. (UMD) format and set `inlineDynamicImports` to true.
3. But when setting `inlineDynamicImports` to true, vite will not be able to handle mutliple entrypoints.

This puts us in a deadlock, now there are two ways around this, either add another separate build pipeline to
the app using vanilla rollup or rspack or something. The second option is to remove sdk building from the main pipeline
and build it separately using Vite itself, toggled by an ENV variable.

`BUILD_MODE=library bin/vite build` should build only the SDK and save it to `public/packs/js/sdk.js`
`bin/vite build` will build the rest of the app as usual. But exclude the SDK.

We need to edit the `asset:precompile` rake task to include the SDK in the precompile list.
*/
import { defineConfig } from 'vite';
import ruby from 'vite-plugin-ruby';
import path from 'path';
import vue from '@vitejs/plugin-vue';

const isLibraryMode = process.env.BUILD_MODE === 'library';
const isTestMode = process.env.TEST === 'true';
const isDevelopment = process.env.NODE_ENV === 'development';

const vueOptions = {
  template: {
    compilerOptions: {
      isCustomElement: tag => ['ninja-keys'].includes(tag),
    },
  },
};

let plugins = [ruby(), vue(vueOptions)];

if (isLibraryMode) {
  plugins = [];
} else if (isTestMode) {
  plugins = [vue(vueOptions)];
}

export default defineConfig({
  plugins: plugins,
  
  // ============================================================================
  // OPTIMIZATIONS FOR DEVELOPMENT HMR
  // ============================================================================
  server: isDevelopment ? {
    // Host configuration for Docker
    host: '0.0.0.0',
    port: 3036,
    strictPort: true,
    
    // HMR configuration optimized for Docker
    hmr: {
      // Use the host that the browser should connect to
      host: process.env.VITE_RUBY_HMR_HOST || 'localhost',
      port: 3036,
      // Use native WebSocket instead of polling
      protocol: 'ws',
    },
    
    // Watch configuration for better file change detection
    watch: {
      // Use native file system events (not polling) for better performance
      usePolling: process.env.CHOKIDAR_USEPOLLING === 'true',
      // Reduce CPU usage by increasing poll interval if polling is enabled
      interval: 300,
      // Ignore heavy directories to reduce watch overhead
      ignored: [
        '**/node_modules/**',
        '**/vendor/**',
        '**/tmp/**',
        '**/log/**',
        '**/.git/**',
        '**/coverage/**',
        '**/public/packs/**',
        '**/docker_data/**',
      ],
    },
    
    // CORS for cross-origin requests
    cors: true,
    
    // Optimize dependency pre-bundling
    fs: {
      // Allow serving files from the project root
      allow: ['.'],
    },
  } : undefined,
  
  // ============================================================================
  // DEPENDENCY OPTIMIZATION
  // ============================================================================
  optimizeDeps: {
    // Pre-bundle dependencies for faster dev server startup
    include: [
      'vue',
      'vue-router',
      'vuex',
      'axios',
      'pinia',
      '@vueuse/core',
      '@vueuse/components',
      'chart.js',
      'vue-chartjs',
      'date-fns',
      'dompurify',
      'highlight.js',
    ],
    // Exclude large dependencies that don't need pre-bundling
    exclude: ['@chatwoot/prosemirror-schema'],
    
    // Force dependency optimization on server start
    force: false,
    
    // Use esbuild for faster dependency pre-bundling
    esbuildOptions: {
      // Increase build speed
      logLevel: 'error',
      target: 'es2020',
    },
  },
  
  // ============================================================================
  // BUILD CONFIGURATION
  // ============================================================================
  build: {
    // Increase chunk size warning limit to avoid warnings
    chunkSizeWarningLimit: 1000,
    
    // Enable source maps in development for better debugging
    sourcemap: isDevelopment ? 'inline' : false,
    
    // Optimize build output
    minify: !isDevelopment ? 'esbuild' : false,
    
    // Target modern browsers for smaller bundle size
    target: 'es2020',
    
    rollupOptions: {
      output: {
        // [NOTE] when not in library mode, no new keys will be addedd or overwritten
        // setting dir: isLibraryMode ? 'public/packs' : undefined will not work
        ...(isLibraryMode
          ? {
              dir: 'public/packs',
              entryFileNames: chunkInfo => {
                if (chunkInfo.name === 'sdk') {
                  return 'js/sdk.js';
                }
                return '[name].js';
              },
            }
          : {}),
        inlineDynamicImports: isLibraryMode, // Disable code-splitting for SDK
        
        // Optimize chunk splitting for better caching
        manualChunks: !isLibraryMode ? {
          // Separate vendor chunks for better caching
          'vue-vendor': ['vue', 'vue-router', 'vuex', 'pinia'],
          'chart-vendor': ['chart.js', 'vue-chartjs'],
          'ui-vendor': ['@vueuse/core', '@vueuse/components'],
        } : undefined,
      },
    },
    
    lib: isLibraryMode
      ? {
          entry: path.resolve(__dirname, './app/javascript/entrypoints/sdk.js'),
          formats: ['iife'], // IIFE format for single file
          name: 'sdk',
        }
      : undefined,
  },
  
  // ============================================================================
  // PATH RESOLUTION
  // ============================================================================
  resolve: {
    alias: {
      vue: 'vue/dist/vue.esm-bundler.js',
      components: path.resolve('./app/javascript/dashboard/components'),
      next: path.resolve('./app/javascript/dashboard/components-next'),
      v3: path.resolve('./app/javascript/v3'),
      dashboard: path.resolve('./app/javascript/dashboard'),
      helpers: path.resolve('./app/javascript/shared/helpers'),
      shared: path.resolve('./app/javascript/shared'),
      survey: path.resolve('./app/javascript/survey'),
      widget: path.resolve('./app/javascript/widget'),
      assets: path.resolve('./app/javascript/dashboard/assets'),
    },
  },
  
  // ============================================================================
  // TEST CONFIGURATION
  // ============================================================================
  test: {
    environment: 'jsdom',
    include: ['app/**/*.{test,spec}.?(c|m)[jt]s?(x)'],
    coverage: {
      reporter: ['lcov', 'text'],
      include: ['app/**/*.js', 'app/**/*.vue'],
      exclude: [
        'app/**/*.@(spec|stories|routes).js',
        '**/specs/**/*',
        '**/i18n/**/*',
      ],
    },
    globals: true,
    outputFile: 'coverage/sonar-report.xml',
    pool: 'threads',
    poolOptions: {
      threads: {
        singleThread: false,
      },
    },
    server: {
      deps: {
        inline: ['tinykeys', '@material/mwc-icon'],
      },
    },
    setupFiles: ['fake-indexeddb/auto', 'vitest.setup.js'],
    mockReset: true,
    clearMocks: true,
  },
});
