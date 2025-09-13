import { exec } from 'child_process';
import { promisify } from 'util';
import fs from 'fs/promises';
import path from 'path';

const execAsync = promisify(exec);

interface ComputerUseConfig {
  displayWidth: number;
  displayHeight: number;
  displayNumber: number;
  version: string;
}

interface ActionResult {
  success: boolean;
  content: string;
  is_error?: boolean;
}

export class ComputerUseTool {
  public config: ComputerUseConfig;
  private screenshotDir: string;

  constructor(config: ComputerUseConfig) {
    this.config = config;
    this.screenshotDir = '/tmp/pulser-screenshots';
    this.ensureScreenshotDir();
  }

  private async ensureScreenshotDir() {
    try {
      await fs.mkdir(this.screenshotDir, { recursive: true });
    } catch (error) {
      console.error('Failed to create screenshot directory:', error);
    }
  }

  async executeAction(input: any): Promise<ActionResult> {
    const { action } = input;

    try {
      switch (action) {
        case 'screenshot':
          return await this.handleScreenshot();
        
        case 'left_click':
        case 'click':
          return await this.handleClick(input.coordinate, 'left');
        
        case 'right_click':
          return await this.handleClick(input.coordinate, 'right');
        
        case 'middle_click':
          return await this.handleClick(input.coordinate, 'middle');
        
        case 'double_click':
          return await this.handleDoubleClick(input.coordinate);
        
        case 'type':
          return await this.handleType(input.text);
        
        case 'key':
          return await this.handleKey(input.key);
        
        case 'mouse_move':
          return await this.handleMouseMove(input.coordinate);
        
        case 'scroll':
          return await this.handleScroll(input);
        
        case 'left_click_drag':
          return await this.handleDrag(input.start_coordinate, input.end_coordinate);
        
        case 'wait':
          return await this.handleWait(input.duration_ms);
        
        default:
          return {
            success: false,
            content: `Unknown action: ${action}`,
            is_error: true,
          };
      }
    } catch (error) {
      return {
        success: false,
        content: `Action failed: ${error.message}`,
        is_error: true,
      };
    }
  }

  async takeScreenshot(): Promise<{ data: string; mimeType: string }> {
    const filename = `screenshot-${Date.now()}.png`;
    const filepath = path.join(this.screenshotDir, filename);

    try {
      // Use scrot to capture screenshot
      await execAsync(
        `DISPLAY=:${this.config.displayNumber} scrot -z ${filepath}`
      );

      // Read and encode as base64
      const imageBuffer = await fs.readFile(filepath);
      const base64Data = imageBuffer.toString('base64');

      // Clean up
      await fs.unlink(filepath);

      return {
        data: base64Data,
        mimeType: 'image/png',
      };
    } catch (error) {
      throw new Error(`Screenshot failed: ${error.message}`);
    }
  }

  private async handleScreenshot(): Promise<ActionResult> {
    try {
      const screenshot = await this.takeScreenshot();
      return {
        success: true,
        content: screenshot.data,
      };
    } catch (error) {
      return {
        success: false,
        content: error.message,
        is_error: true,
      };
    }
  }

  private async handleClick(
    coordinate: [number, number],
    button: string
  ): Promise<ActionResult> {
    const [x, y] = coordinate;
    
    // Validate coordinates
    if (x < 0 || x >= this.config.displayWidth || 
        y < 0 || y >= this.config.displayHeight) {
      return {
        success: false,
        content: `Coordinates (${x}, ${y}) are outside display bounds`,
        is_error: true,
      };
    }

    // Map button names to xdotool button numbers
    const buttonMap = { left: '1', middle: '2', right: '3' };
    const buttonNum = buttonMap[button] || '1';

    try {
      await execAsync(
        `DISPLAY=:${this.config.displayNumber} xdotool mousemove ${x} ${y} click ${buttonNum}`
      );
      
      return {
        success: true,
        content: `Clicked at (${x}, ${y}) with ${button} button`,
      };
    } catch (error) {
      return {
        success: false,
        content: `Click failed: ${error.message}`,
        is_error: true,
      };
    }
  }

  private async handleDoubleClick(coordinate: [number, number]): Promise<ActionResult> {
    const [x, y] = coordinate;

    try {
      await execAsync(
        `DISPLAY=:${this.config.displayNumber} xdotool mousemove ${x} ${y} click --repeat 2 --delay 100 1`
      );
      
      return {
        success: true,
        content: `Double-clicked at (${x}, ${y})`,
      };
    } catch (error) {
      return {
        success: false,
        content: `Double-click failed: ${error.message}`,
        is_error: true,
      };
    }
  }

  async typeText(text: string): Promise<void> {
    // Escape special characters for shell
    const escapedText = text.replace(/['"\\]/g, '\\$&');
    
    await execAsync(
      `DISPLAY=:${this.config.displayNumber} xdotool type "${escapedText}"`
    );
  }

  private async handleType(text: string): Promise<ActionResult> {
    try {
      await this.typeText(text);
      return {
        success: true,
        content: `Typed: "${text}"`,
      };
    } catch (error) {
      return {
        success: false,
        content: `Type failed: ${error.message}`,
        is_error: true,
      };
    }
  }

  async keyPress(params: { key: string; modifiers?: string[] }): Promise<void> {
    const { key, modifiers = [] } = params;
    
    // Build key combination
    const keys = [...modifiers, key].join('+');
    
    await execAsync(
      `DISPLAY=:${this.config.displayNumber} xdotool key ${keys}`
    );
  }

  private async handleKey(key: string): Promise<ActionResult> {
    try {
      // Parse key combination (e.g., "ctrl+s")
      const parts = key.split('+');
      const modifiers = parts.slice(0, -1);
      const mainKey = parts[parts.length - 1];

      await this.keyPress({ key: mainKey, modifiers });
      
      return {
        success: true,
        content: `Pressed: ${key}`,
      };
    } catch (error) {
      return {
        success: false,
        content: `Key press failed: ${error.message}`,
        is_error: true,
      };
    }
  }

  private async handleMouseMove(coordinate: [number, number]): Promise<ActionResult> {
    const [x, y] = coordinate;

    try {
      await execAsync(
        `DISPLAY=:${this.config.displayNumber} xdotool mousemove ${x} ${y}`
      );
      
      return {
        success: true,
        content: `Moved mouse to (${x}, ${y})`,
      };
    } catch (error) {
      return {
        success: false,
        content: `Mouse move failed: ${error.message}`,
        is_error: true,
      };
    }
  }

  private async handleScroll(input: any): Promise<ActionResult> {
    const { coordinate, scroll_direction, scroll_amount = 3 } = input;
    const [x, y] = coordinate;

    try {
      // Move to position first
      await execAsync(
        `DISPLAY=:${this.config.displayNumber} xdotool mousemove ${x} ${y}`
      );

      // Scroll (button 4 = up, 5 = down, 6 = left, 7 = right)
      const scrollMap = {
        up: '4',
        down: '5',
        left: '6',
        right: '7',
      };
      const button = scrollMap[scroll_direction] || '5';

      for (let i = 0; i < scroll_amount; i++) {
        await execAsync(
          `DISPLAY=:${this.config.displayNumber} xdotool click ${button}`
        );
        await new Promise(resolve => setTimeout(resolve, 50));
      }
      
      return {
        success: true,
        content: `Scrolled ${scroll_direction} ${scroll_amount} times at (${x}, ${y})`,
      };
    } catch (error) {
      return {
        success: false,
        content: `Scroll failed: ${error.message}`,
        is_error: true,
      };
    }
  }

  private async handleDrag(
    start: [number, number],
    end: [number, number]
  ): Promise<ActionResult> {
    const [x1, y1] = start;
    const [x2, y2] = end;

    try {
      await execAsync(
        `DISPLAY=:${this.config.displayNumber} xdotool mousemove ${x1} ${y1} mousedown 1 mousemove ${x2} ${y2} mouseup 1`
      );
      
      return {
        success: true,
        content: `Dragged from (${x1}, ${y1}) to (${x2}, ${y2})`,
      };
    } catch (error) {
      return {
        success: false,
        content: `Drag failed: ${error.message}`,
        is_error: true,
      };
    }
  }

  private async handleWait(duration_ms: number): Promise<ActionResult> {
    const maxWait = 10000; // 10 seconds max
    const actualWait = Math.min(duration_ms, maxWait);
    
    await new Promise(resolve => setTimeout(resolve, actualWait));
    
    return {
      success: true,
      content: `Waited ${actualWait}ms`,
    };
  }

  async click(params: { x: number; y: number; button?: string }): Promise<void> {
    const result = await this.handleClick([params.x, params.y], params.button || 'left');
    if (!result.success) {
      throw new Error(result.content);
    }
  }
}