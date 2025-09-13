import { exportPNGs } from "./sdk.js";

const FILE_ID = process.env.FIGMA_FILE_ID_HEALTH || "MxZzjY9lcdl9sYERJfAFYN"; // Health Dashboard file
const outputDir = "design/figma-refs";

// Key component frames from your Health Dashboard
const componentNodes = [
  "78:187",     // KPI Donut component
  "cmp/KPI_Donut",
  "cmp/Trend_Line", 
  "cmp/World_Choropleth",
  "cmp/Card",
  "cmp/Table_Row"
];

console.log(`🖼️  Exporting reference frames from Figma file: ${FILE_ID}`);
console.log(`📍 Nodes to export: ${componentNodes.join(', ')}`);

try {
  await exportPNGs(FILE_ID, componentNodes, outputDir);
  console.log(`✅ Reference frames exported to ${outputDir}/`);
} catch (error) {
  console.error('❌ Failed to export frames:', error);
  process.exit(1);
}