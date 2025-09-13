import fs from "node:fs";
const system = fs.readFileSync("agents/lyra_gpt5/LYRA_GPT5_SYSTEM_PROMPT.txt","utf8");
const input = JSON.parse(fs.readFileSync(process.argv[2] || "agents/lyra_gpt5/examples/demo.input.json","utf8"));
const payload = { system, input }; // hand this to your GPT-5 caller
console.log(JSON.stringify(payload, null, 2));