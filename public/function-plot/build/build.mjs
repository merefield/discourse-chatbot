import fs from "node:fs";
import path from "node:path";
import { build } from "esbuild";

const output = "../1.26.0";
const result = await build({
  entryPoints: ["entry.js"],
  outfile: `${output}/function-plot.js`,
  bundle: true,
  minify: true,
  format: "iife",
  target: "es2022",
  legalComments: "inline",
  metafile: true,
});

const packages = new Map();
for (const input of Object.keys(result.metafile.inputs)) {
  let directory = path.dirname(fs.realpathSync(input));
  while (!fs.existsSync(path.join(directory, "package.json"))) {
    directory = path.dirname(directory);
  }
  const metadata = JSON.parse(
    fs.readFileSync(path.join(directory, "package.json"))
  );
  if (metadata.name === "chatbot-function-plot-vendor") {
    continue;
  }
  const license = fs
    .readdirSync(directory)
    .find((name) => /^license(?:\..*)?$/i.test(name));
  let text;
  if (license) {
    text = fs.readFileSync(path.join(directory, license), "utf8");
  } else if (
    ["built-in-math-eval", "interval-arithmetic-eval", "mr-parser"].includes(
      metadata.name
    )
  ) {
    // These published packages omit LICENSE but retain this notice in index.js.
    text = fs
      .readFileSync(path.join(output, "LICENSE"), "utf8")
      .replace(/Copyright[^\n]*/, "Copyright (c) 2015 Mauricio Poppe");
  } else {
    throw new Error(`Missing license for ${metadata.name}`);
  }
  packages.set(`${metadata.name}@${metadata.version}`, text.trim());
}
const notices = [...packages]
  .sort(([left], [right]) => left.localeCompare(right))
  .map(([name, text]) => `${name}\n${text}`)
  .join("\n\n");
fs.writeFileSync(`${output}/THIRD-PARTY-LICENSES.txt`, `${notices}\n`);
