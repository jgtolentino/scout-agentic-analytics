import Ajv from "ajv";
import fs from "node:fs";
const schema = JSON.parse(fs.readFileSync("agents/lyra_gpt5/contract/lyra.contract.json","utf8"));
const input = JSON.parse(fs.readFileSync(process.argv[2] || "agents/lyra_gpt5/examples/demo.input.json","utf8"));
const ajv = new Ajv({allErrors:true, strict:true});
const validate = ajv.compile(schema);
if (!validate(input)) {
  console.error(JSON.stringify(validate.errors, null, 2));
  process.exit(1);
}
console.log("LyraInput ✅ valid");