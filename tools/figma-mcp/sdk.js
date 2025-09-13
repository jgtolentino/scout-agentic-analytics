// MCP Figma SDK wrapper
import { exec } from 'node:child_process';
import { promisify } from 'node:util';
import fs from 'node:fs';
import path from 'node:path';

const execAsync = promisify(exec);

export async function getVariables(fileId) {
  try {
    const { stdout } = await execAsync(`claude "Use mcp__figma__get_variables to extract design tokens from file ${fileId}"`);
    return JSON.parse(stdout.trim());
  } catch (error) {
    console.error('Failed to get variables:', error);
    // Fallback to direct Figma API if MCP fails
    return await getFigmaVariablesAPI(fileId);
  }
}

export async function exportPNGs(fileId, nodeIds, outputDir) {
  fs.mkdirSync(outputDir, { recursive: true });
  
  for (const nodeId of nodeIds) {
    try {
      const { stdout } = await execAsync(`claude "Use mcp__figma__export_image to export ${nodeId} from file ${fileId} as PNG"`);
      const result = JSON.parse(stdout.trim());
      
      if (result.imageUrl) {
        // Download and save the PNG
        const response = await fetch(result.imageUrl);
        const buffer = await response.arrayBuffer();
        const filename = nodeId.replace(/[\/\\]/g, '_') + '.png';
        fs.writeFileSync(path.join(outputDir, filename), Buffer.from(buffer));
        console.log(`✅ Exported ${filename}`);
      }
    } catch (error) {
      console.error(`Failed to export ${nodeId}:`, error);
    }
  }
}

async function getFigmaVariablesAPI(fileId) {
  const token = process.env.FIGMA_TOKEN;
  if (!token) throw new Error('FIGMA_TOKEN not set');
  
  const response = await fetch(`https://api.figma.com/v1/files/${fileId}/variables/local`, {
    headers: { 'X-Figma-Token': token }
  });
  
  if (!response.ok) {
    throw new Error(`Figma API error: ${response.status}`);
  }
  
  return await response.json();
}