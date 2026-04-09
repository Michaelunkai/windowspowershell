import js from "@eslint/js";
import stylistic from "@stylistic/eslint-plugin";
import perfectionist from "eslint-plugin-perfectionist";
import reactHooks from "eslint-plugin-react-hooks";
import reactRefresh from "eslint-plugin-react-refresh";
import { defineConfig, globalIgnores } from "eslint/config";
import globals from "globals";

export default defineConfig([
  globalIgnores(["dist"]),
  {
    files: ["**/*.{js,jsx}"],
    extends: [
      js.configs.recommended,
      reactHooks.configs.flat["recommended-latest"],
      reactRefresh.configs.vite
    ],
    languageOptions: {
      globals: globals.browser,
      parserOptions: {
        ecmaVersion: "latest",
        ecmaFeatures: { jsx: true },
        sourceType: "module"
      }
    },
    plugins: {
      "@stylistic": stylistic,
      perfectionist
    },
    rules: {
      "no-unused-vars": ["error", {
        varsIgnorePattern: "^[A-Z_]",
        caughtErrorsIgnorePattern: "^_",
        argsIgnorePattern: "^_"
      }],
      semi: ["error"],
      "@stylistic/quotes": ["error", "double", { allowTemplateLiterals: "avoidEscape" }],
      "perfectionist/sort-imports": ["error"],
      "@stylistic/quote-props": ["error", "as-needed"],
      "@stylistic/comma-dangle": ["error", "never"],
      "prefer-const": ["error"],
      curly: ["error", "all"],
      "@stylistic/indent": ["error", 2],
      "@stylistic/arrow-parens": ["error", "as-needed"],
      "@stylistic/object-curly-spacing": ["error", "always"],
      "@stylistic/brace-style": "error",
      "@stylistic/no-trailing-spaces": "error",
      "@stylistic/eol-last": ["error", "always"],
      "@stylistic/no-multiple-empty-lines": ["error", {
        max: 1, maxEOF: 0, maxBOF: 0
      }],
      "@stylistic/comma-spacing": ["error", { before: false, after: true }]
    }
  }
]);
