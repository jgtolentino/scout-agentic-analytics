import fs from "node:fs";

// Configure your API details
const API_KEY = process.env.OPENAI_API_KEY || "sk-your-api-key";
const MODEL = "gpt-4-turbo-preview"; // Change to "gpt-5" when available
const ENDPOINT = "https://api.openai.com/v1/chat/completions";

async function optimizeWithLyra(inputPath) {
  // Read Lyra system prompt and input
  const system = fs.readFileSync("agents/lyra_gpt5/LYRA_GPT5_SYSTEM_PROMPT.txt", "utf8");
  const input = JSON.parse(fs.readFileSync(inputPath, "utf8"));
  
  // Create the request
  const request = {
    model: MODEL,
    messages: [
      { role: "system", content: system },
      { role: "user", content: JSON.stringify(input) }
    ],
    temperature: 0.2,
    response_format: { type: "json_object" }
  };
  
  // Send to OpenAI
  const response = await fetch(ENDPOINT, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${API_KEY}`
    },
    body: JSON.stringify(request)
  });
  
  const data = await response.json();
  
  if (data.error) {
    console.error("API Error:", data.error);
    return null;
  }
  
  // Extract the optimized prompt from response
  const lyraOutput = JSON.parse(data.choices[0].message.content);
  
  // Now send the optimized prompt to GPT-5
  const finalRequest = {
    model: MODEL,
    messages: [
      { role: "user", content: lyraOutput.optimized_prompt }
    ],
    temperature: input.target_model?.temperature || 0.2,
    response_format: { type: "json_object" }
  };
  
  const finalResponse = await fetch(ENDPOINT, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${API_KEY}`
    },
    body: JSON.stringify(finalRequest)
  });
  
  return {
    lyra_output: lyraOutput,
    final_result: await finalResponse.json()
  };
}

// Usage
const inputPath = process.argv[2] || "agents/lyra_gpt5/examples/demo.input.json";
const result = await optimizeWithLyra(inputPath);
console.log(JSON.stringify(result, null, 2));