const StyleDictionary = require('style-dictionary');
const { registerTransforms } = require('@tokens-studio/sd-transforms');

// Register Tokens Studio transforms for enhanced DTCG support
registerTransforms(StyleDictionary);

module.exports = {
  source: ['tokens/primitives.json'],
  platforms: {
    // CSS Custom Properties (for runtime theming)
    css: {
      transformGroup: 'css',
      buildPath: 'packages/ui-components/src/tokens/generated/',
      files: [
        {
          destination: 'tokens.css',
          format: 'css/variables',
          options: {
            outputReferences: true
          }
        }
      ]
    },
    
    // TypeScript constants (for compile-time usage)
    js: {
      transformGroup: 'js',
      buildPath: 'packages/ui-components/src/tokens/generated/',
      files: [
        {
          destination: 'tokens.ts',
          format: 'typescript/es6-declarations',
          options: {
            outputReferences: false
          }
        }
      ]
    },
    
    // JSON for documentation/tooling
    json: {
      transformGroup: 'js',
      buildPath: 'packages/ui-components/src/tokens/generated/',
      files: [
        {
          destination: 'tokens.json',
          format: 'json/flat'
        }
      ]
    },
    
    // SCSS variables (for Sass builds)
    scss: {
      transformGroup: 'scss',
      buildPath: 'packages/ui-components/src/tokens/generated/',
      files: [
        {
          destination: '_tokens.scss',
          format: 'scss/variables'
        }
      ]
    }
  },
  
  // Custom transforms for Scout-specific needs
  transform: {
    'size/px-to-rem': {
      type: 'value',
      matcher: (token) => token.type === 'dimension' && token.value.endsWith('px'),
      transformer: (token) => {
        const px = parseFloat(token.value);
        return `${px / 16}rem`;
      }
    },
    
    'color/hex-alpha': {
      type: 'value',
      matcher: (token) => token.type === 'color' && token.value.length > 7,
      transformer: (token) => {
        const hex = token.value;
        if (hex.length === 9) {
          const alpha = parseInt(hex.slice(7, 9), 16) / 255;
          return `rgba(${parseInt(hex.slice(1, 3), 16)}, ${parseInt(hex.slice(3, 5), 16)}, ${parseInt(hex.slice(5, 7), 16)}, ${alpha.toFixed(3)})`;
        }
        return hex;
      }
    }
  },
  
  // Custom formats for Scout design system
  format: {
    'typescript/es6-declarations': function({ dictionary }) {
      return `/**
 * Scout Design Tokens
 * Generated from DTCG tokens via Style Dictionary
 * Do not edit directly - regenerate using 'npm run tokens:build'
 */

export const tokens = ${JSON.stringify(dictionary.tokens, null, 2)};

// Convenience exports for common token categories
export const colors = ${JSON.stringify(dictionary.tokens.color || {}, null, 2)};
export const sizes = ${JSON.stringify(dictionary.tokens.size || {}, null, 2)};
export const typography = ${JSON.stringify(dictionary.tokens.font || {}, null, 2)};
export const shadows = ${JSON.stringify(dictionary.tokens.shadow || {}, null, 2)};
export const zIndex = ${JSON.stringify(dictionary.tokens.z || {}, null, 2)};
export const opacity = ${JSON.stringify(dictionary.tokens.opacity || {}, null, 2)};

export default tokens;
`;
    }
  }
};