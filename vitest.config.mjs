import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    coverage: {
      include: ['hearth-start/src/main/frontend/**/*.{js,jsx}'],
      provider: 'v8',
      reporter: ['text'],
      thresholds: {
        branches: 100,
        functions: 100,
        lines: 100,
        statements: 100
      }
    },
    environment: 'happy-dom',
    globals: true,
    include: [
      '**/__tests__/**/*.test.{js,jsx}',
      '**/src/test/js/**/*.test.{js,jsx}',
      '**/src/main/frontend/**/*.test.{js,jsx}'
    ],
    setupFiles: ['./jest.setup.js']
  }
});
