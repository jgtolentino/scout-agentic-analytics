import fs from "node:fs";
import path from "node:path";
import { getVariables } from "./sdk.js";

const FILE_ID = process.env.FIGMA_FILE_ID_R19 || "MxZzjY9lcdl9sYERJfAFYN"; // r19 Data Viz Kit
const outputPath = "design/tokens/design.tokens.json";

console.log(`🎨 Exporting design tokens from Figma file: ${FILE_ID}`);

try {
  const variables = await getVariables(FILE_ID);
  
  // Transform Figma variables to design tokens format
  const designTokens = {
    color: {},
    spacing: {},
    typography: {},
    radius: {}
  };

  // Process Figma variables into structured tokens
  if (variables.meta && variables.meta.variables) {
    Object.values(variables.meta.variables).forEach(variable => {
      const { name, valuesByMode } = variable;
      const value = Object.values(valuesByMode)[0]; // Use first mode
      
      if (name.startsWith('color/')) {
        const tokenName = name.replace('color/', '').replace('/', '-');
        designTokens.color[tokenName] = { value: value.r ? `rgba(${Math.round(value.r*255)}, ${Math.round(value.g*255)}, ${Math.round(value.b*255)}, ${value.a || 1})` : value };
      } else if (name.startsWith('spacing/')) {
        const tokenName = name.replace('spacing/', '');
        designTokens.spacing[tokenName] = { value: `${value}px` };
      } else if (name.startsWith('radius/')) {
        const tokenName = name.replace('radius/', '');
        designTokens.radius[tokenName] = { value: `${value}px` };
      }
    });
  }

  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, JSON.stringify(designTokens, null, 2));
  
  console.log(`✅ Design tokens exported to ${outputPath}`);
  console.log(`📊 Tokens exported: ${Object.keys(designTokens.color).length} colors, ${Object.keys(designTokens.spacing).length} spacing, ${Object.keys(designTokens.radius).length} radius`);
} catch (error) {
  console.error('❌ Failed to export design tokens:', error);
  process.exit(1);
}