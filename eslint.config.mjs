import js from '@eslint/js';
import globals from 'globals';

export default [
    {
        ignores: ['node_modules/**', 'hearth-*/target/**']
    },
    js.configs.recommended,
    {
        files: ['hearth-start/src/main/frontend/**/*.{js,jsx}', 'hearth-start/src/main/resources/static/js/**/*.js'],
        languageOptions: {
            ecmaVersion: 'latest',
            sourceType: 'script',
            parserOptions: { ecmaFeatures: { jsx: true } },
            globals: {...globals.browser, Vditor: 'readonly'}
        },
        rules: {
            'no-var': 'error',
            'prefer-const': 'error',
            'no-console': 'error',
            'no-unused-vars': ['error', {args: 'none'}],
            eqeqeq: ['error', 'always'],
            curly: 'error',
            'no-eval': 'error'
        }
    },
    {
        files: ['hearth-start/src/main/frontend/**/*.{js,jsx}'],
        languageOptions: {
            sourceType: 'module',
            parserOptions: { ecmaVersion: 'latest', ecmaFeatures: { jsx: true } },
            globals: { describe: 'readonly', beforeEach: 'readonly', it: 'readonly', expect: 'readonly' },
        },
        rules: { 'no-unused-vars': ['error', { varsIgnorePattern: '^React$' }] },
    },
    {
        files: ['**/src/test/js/**/*.test.js', 'tests/**/*.js'],
        languageOptions: {
            globals: {...globals.browser, ...globals.node, ...globals.jest}
        },
        rules: {
            'no-eval': 'off'
        }
    },
    {
        files: ['playwright.config.mjs'],
        languageOptions: {
            globals: globals.node
        }
    }
];
