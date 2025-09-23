// LLM integration for Ask Suqi planning system
// Supports both Claude (Anthropic) and GPT (OpenAI)

export interface LLMClient {
  complete(system: string, prompt: string): Promise<string>;
}

class MockLLMClient implements LLMClient {
  async complete(system: string, prompt: string): Promise<string> {
    // Mock response for development
    if (prompt.toLowerCase().includes('revenue') || prompt.toLowerCase().includes('sales')) {
      return JSON.stringify({
        intent: "Get revenue analytics",
        steps: [
          {
            tool: "SEMANTIC_QUERY",
            params: {
              dimensions: ["category"],
              measures: ["revenue", "transactions"],
              rollup: true
            },
            reason: "User asked for revenue data by category"
          }
        ]
      });
    }

    if (prompt.toLowerCase().includes('map') || prompt.toLowerCase().includes('geo')) {
      return JSON.stringify({
        intent: "Geographic visualization",
        steps: [
          {
            tool: "GEO_EXPORT",
            params: {
              level: "city",
              metric: "revenue"
            },
            reason: "User requested geographic/map visualization"
          }
        ]
      });
    }

    // Default fallback
    return JSON.stringify({
      intent: "Information request",
      steps: [
        {
          tool: "CATALOG_QA",
          params: {
            question: prompt.split('\n')[1] || prompt // Extract user query
          },
          reason: "General information or definition request"
        }
      ]
    });
  }
}

class AnthropicClient implements LLMClient {
  private apiKey: string;

  constructor(apiKey: string) {
    this.apiKey = apiKey;
  }

  async complete(system: string, prompt: string): Promise<string> {
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': this.apiKey,
        'anthropic-version': '2023-06-01'
      },
      body: JSON.stringify({
        model: 'claude-3-sonnet-20240229',
        max_tokens: 1000,
        temperature: 0.2,
        system,
        messages: [
          {
            role: 'user',
            content: prompt
          }
        ]
      })
    });

    if (!response.ok) {
      throw new Error(`Anthropic API error: ${response.status}`);
    }

    const data = await response.json();
    return data.content[0].text;
  }
}

class OpenAIClient implements LLMClient {
  private apiKey: string;

  constructor(apiKey: string) {
    this.apiKey = apiKey;
  }

  async complete(system: string, prompt: string): Promise<string> {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${this.apiKey}`
      },
      body: JSON.stringify({
        model: 'gpt-4',
        temperature: 0.2,
        max_tokens: 1000,
        messages: [
          {
            role: 'system',
            content: system
          },
          {
            role: 'user',
            content: prompt
          }
        ]
      })
    });

    if (!response.ok) {
      throw new Error(`OpenAI API error: ${response.status}`);
    }

    const data = await response.json();
    return data.choices[0].message.content;
  }
}

export function chooseLLM(): LLMClient {
  const provider = process.env.LLM_PROVIDER?.toLowerCase() || 'mock';

  switch (provider) {
    case 'claude':
    case 'anthropic':
      if (!process.env.ANTHROPIC_API_KEY) {
        console.warn('ANTHROPIC_API_KEY not set, falling back to mock LLM');
        return new MockLLMClient();
      }
      return new AnthropicClient(process.env.ANTHROPIC_API_KEY);

    case 'gpt':
    case 'openai':
      if (!process.env.OPENAI_API_KEY) {
        console.warn('OPENAI_API_KEY not set, falling back to mock LLM');
        return new MockLLMClient();
      }
      return new OpenAIClient(process.env.OPENAI_API_KEY);

    case 'mock':
    default:
      return new MockLLMClient();
  }
}