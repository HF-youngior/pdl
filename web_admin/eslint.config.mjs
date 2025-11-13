import js from '@eslint/js';
import globals from 'globals';

export default [
  js.configs.recommended,
  {
    languageOptions: {
      globals: {
        ...globals.browser,
        ...globals.es2021,
      },
      ecmaVersion: 2021,
      sourceType: 'commonjs',
    },
    rules: {
      // 允许 console
      'no-console': 'off',
      // 允许未使用的变量（以 _ 开头）
      'no-unused-vars': ['warn', { 
        argsIgnorePattern: '^_',
        varsIgnorePattern: '^_',
        caughtErrorsIgnorePattern: '^_',
      }],
      // 允许使用 var（向后兼容）
      'no-var': 'off',
      // 允许空代码块
      'no-empty': ['warn', { allowEmptyCatch: true }],
    },
  },
];




