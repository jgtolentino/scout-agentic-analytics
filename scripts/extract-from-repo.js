#!/usr/bin/env node
/* Extracts design/brand tokens from a code repo into DTCG JSON.
   Supports: CSS custom properties, SCSS/LESS vars, crude theme objects. */
const fs = require('fs');
const path = require('path');
const fg = require('fast-glob');
const postcss = require('postcss');
const safeParser = require('postcss-safe-parser');
const { colord, extend } = require('colord');
extend([require('colord/plugins/names')]);
const sass = require('sass');
const less = require('less');

const REPO = process.argv[2] || '.';
const OUT_DIR = path.resolve('tokens');
fs.mkdirSync(OUT_DIR, { recursive: true });

const filesByType = async () => {
  const patterns = [
    '**/*.{css,scss,less}',
    'tailwind.config.{js,cjs,mjs,ts}',
    '**/*theme*.{js,ts}',
    '**/*tokens*.{json,js,ts}'
  ];
  const entries = await fg(patterns, { cwd: REPO, ignore: ['**/node_modules/**', '**/dist/**', '**/build/**'], dot: true });
  const bucket = { css: [], scss: [], less: [], js: [], json: [] };
  for (const rel of entries) {
    const abs = path.join(REPO, rel);
    if (rel.endsWith('.css')) bucket.css.push(abs);
    else if (rel.endsWith('.scss')) bucket.scss.push(abs);
    else if (rel.endsWith('.less')) bucket.less.push(abs);
    else if (rel.endsWith('.json')) bucket.json.push(abs);
    else bucket.js.push(abs);
  }
  return bucket;
};

const toHex = (v) => {
  const c = colord(String(v).trim());
  if (!c.isValid()) return null;
  const a = c.alpha();
  return a < 1 ? c.toHex() + Math.round(a * 255).toString(16).padStart(2, '0') : c.toHex();
};

const collect = {
  color: new Map(),
  sizeSpacing: new Map(),
  sizeRadius: new Map(),
  sizeFont: new Map(),
  sizeLine: new Map(),
  sizeBreakpoint: new Map(),
  shadow: new Map(),
  zIndex: new Map(),
  opacity: new Map(),
  fontFamily: new Map(),
};

const put = (map, key, val) => {
  if (!key || val == null) return;
  if (!map.has(key)) map.set(key, val);
};

// heuristics
const isPxNumber = (v) => /^\d+(\.\d+)?px$/.test(v);
const isRemEm = (v) => /^\d+(\.\d+)?(rem|em)$/.test(v);
const isSpacing = (prop) => /^(margin|padding|gap|inset|top|left|right|bottom|width|height|min-|max-)/.test(prop) || prop === 'letter-spacing';
const isRadius = (prop) => /radius$/.test(prop);
const isFontSize = (prop) => prop === 'font-size';
const isLineHeight = (prop) => prop === 'line-height';
const isShadow = (prop, val) => prop === 'box-shadow' && val && val !== 'none';
const isZ = (prop) => prop === 'z-index';
const isOpacity = (prop) => prop === 'opacity';
const colorProps = new Set(['color','background','background-color','border-color','border-top-color','border-right-color','border-bottom-color','border-left-color','outline-color','fill','stroke']);

const normalizeName = (name) =>
  String(name).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');

async function parseCssFile(file) {
  const css = fs.readFileSync(file, 'utf8');
  const root = postcss.parse(css, { parser: safeParser });
  root.walkDecls(decl => {
    const prop = decl.prop.trim();
    const value = decl.value.trim();

    // CSS custom properties
    if (prop.startsWith('--')) {
      const n = normalizeName(prop.replace(/^--/, ''));
      if (colorProps.has(n) || /(color|brand|accent|primary|secondary)/.test(n)) {
        const hex = toHex(value);
        if (hex) put(collect.color, n, hex);
      }
      if (/(radius|rounded)/.test(n) && (isPxNumber(value) || isRemEm(value))) put(collect.sizeRadius, n, value);
      if (/(spacing|space|gap|gutter|size|scale)/.test(n) && (isPxNumber(value) || isRemEm(value))) put(collect.sizeSpacing, n, value);
      if (/(font|text).*size/.test(n) && (isPxNumber(value) || isRemEm(value))) put(collect.sizeFont, n, value);
      if (/line.*height/.test(n) && (isPxNumber(value) || isRemEm(value) || /^\d+(\.\d+)?$/.test(value))) put(collect.sizeLine, n, value);
      if (/shadow/.test(n) && isShadow('box-shadow', value)) put(collect.shadow, n, value);
      if (/z-index|zindex|layer/.test(n) && /^\d+$/.test(value)) put(collect.zIndex, n, Number(value));
      if (/opacity/.test(n) && /^0(\.\d+)?|1(\.0+)?$/.test(value)) put(collect.opacity, n, Number(value));
      if (/font.*family/.test(n)) put(collect.fontFamily, n, value.replace(/["']/g, ''));
    }

    // raw declarations
    if (colorProps.has(prop)) {
      const hex = toHex(value);
      if (hex) put(collect.color, `${normalizeName(prop)}-${hex.slice(1,7)}`, hex);
    }
    if (isSpacing(prop) && (isPxNumber(value) || isRemEm(value))) put(collect.sizeSpacing, `${normalizeName(prop)}-${value}`, value);
    if (isRadius(prop) && (isPxNumber(value) || isRemEm(value))) put(collect.sizeRadius, `${normalizeName(prop)}-${value}`, value);
    if (isFontSize(prop) && (isPxNumber(value) || isRemEm(value))) put(collect.sizeFont, `${normalizeName(prop)}-${value}`, value);
    if (isLineHeight(prop) && (isPxNumber(value) || isRemEm(value) || /^\d+(\.\d+)?$/.test(value))) put(collect.sizeLine, `${normalizeName(prop)}-${value}`, value);
    if (isShadow(prop, value)) put(collect.shadow, normalizeName(value), value);
    if (isZ(prop) && /^\d+$/.test(value)) put(collect.zIndex, `z-${value}`, Number(value));
    if (isOpacity(prop) && /^0(\.\d+)?|1(\.0+)?$/.test(value)) put(collect.opacity, `opacity-${value}`, Number(value));
  });

  // media breakpoints
  root.walkAtRules('media', (rule) => {
    const text = rule.params;
    const m = text.match(/\(min-width:\s*(\d+)px\)|\(max-width:\s*(\d+)px\)/gi);
    if (m) {
      m.forEach(x => {
        const num = Number(String(x).match(/(\d+)px/)[1]);
        put(collect.sizeBreakpoint, `bp-${num}`, `${num}px`);
      });
    }
  });

  // @font-face
  root.walkAtRules('font-face', (rule) => {
    let fam;
    rule.walkDecls('font-family', (d) => fam = d.value.replace(/["']/g, ''));
    if (fam) put(collect.fontFamily, normalizeName(fam), fam);
  });
}

function parseScssVars(file) {
  // naive: $name: value; ignores maps/functions; good enough for first pass
  const txt = fs.readFileSync(file, 'utf8');
  const re = /^\s*\$([a-z0-9\-_]+)\s*:\s*([^;]+);/gim;
  let m;
  while ((m = re.exec(txt))) {
    const name = normalizeName(m[1]); const val = m[2].trim();
    if (toHex(val)) put(collect.color, name, toHex(val));
    else if (/shadow/.test(name)) put(collect.shadow, name, val);
    else if (/radius/.test(name) && (isPxNumber(val) || isRemEm(val))) put(collect.sizeRadius, name, val);
    else if (/font.*size/.test(name) && (isPxNumber(val) || isRemEm(val))) put(collect.sizeFont, name, val);
    else if (/line.*height/.test(name) && (isPxNumber(val) || isRemEm(val) || /^\d+(\.\d+)?$/.test(val))) put(collect.sizeLine, name, val);
    else if (/spacing|space|gap|gutter/.test(name) && (isPxNumber(val) || isRemEm(val))) put(collect.sizeSpacing, name, val);
    else if (/z-?index|layer/.test(name) && /^\d+$/.test(val)) put(collect.zIndex, name, Number(val));
  }
}

function parseLessVars(file) {
  const txt = fs.readFileSync(file, 'utf8');
  const re = /^\s*@([a-z0-9\-_]+)\s*:\s*([^;]+);/gim;
  let m;
  while ((m = re.exec(txt))) {
    const name = normalizeName(m[1]); const val = m[2].trim();
    if (toHex(val)) put(collect.color, name, toHex(val));
    else if (/shadow/.test(name)) put(collect.shadow, name, val);
    else if (/radius/.test(name) && (isPxNumber(val) || isRemEm(val))) put(collect.sizeRadius, name, val);
    else if (/font.*size/.test(name) && (isPxNumber(val) || isRemEm(val))) put(collect.sizeFont, name, val);
    else if (/line.*height/.test(name) && (isPxNumber(val) || isRemEm(val) || /^\d+(\.\d+)?$/.test(val))) put(collect.sizeLine, name, val);
    else if (/spacing|space|gap|gutter/.test(name) && (isPxNumber(val) || isRemEm(val))) put(collect.sizeSpacing, name, val);
    else if (/z-?index|layer/.test(name) && /^\d+$/.test(val)) put(collect.zIndex, name, Number(val));
  }
}

async function main() {
  const files = await filesByType();

  console.log(`🔍 Scanning ${REPO} for design tokens...`);
  console.log(`📁 Found: ${files.css.length} CSS, ${files.scss.length} SCSS, ${files.less.length} LESS, ${files.js.length} JS files`);

  // 1) CSS files (including built CSS from frameworks)
  for (const f of files.css) await parseCssFile(f);

  // 2) SCSS: parse variables textually; also compile to CSS and re-scan (captures :root vars)
  for (const f of files.scss) {
    parseScssVars(f);
    try {
      const css = sass.compile(f, { style: 'expanded' }).css;
      const tmp = path.join(OUT_DIR, '.tmp.css');
      fs.writeFileSync(tmp, css);
      await parseCssFile(tmp);
      fs.unlinkSync(tmp);
    } catch { /* ignore */ }
  }

  // 3) LESS: parse variables + compile to CSS and re-scan
  for (const f of files.less) {
    parseLessVars(f);
    try {
      const css = (await less.render(fs.readFileSync(f, 'utf8'))).css;
      const tmp = path.join(OUT_DIR, '.tmp.less.css');
      fs.writeFileSync(tmp, css);
      await parseCssFile(tmp);
      fs.unlinkSync(tmp);
    } catch { /* ignore */ }
  }

  // 4) Optional: Tailwind theme / JS theme objects (best-effort)
  for (const f of files.js) {
    const base = path.basename(f).toLowerCase();
    if (!/tailwind\.config|theme|tokens/.test(base)) continue;
    try {
      // Dangerous in general; acceptable for local repos you trust
      const mod = require(path.resolve(f));
      const theme = (mod && (mod.theme || mod.default?.theme)) || (mod?.extendTheme ? mod : null) || mod?.default || mod;
      const t = theme?.theme || theme;
      const colors = t?.colors || t?.palette;
      if (colors && typeof colors === 'object') {
        const flatten = (obj, pfx=[]) => {
          Object.entries(obj).forEach(([k, v]) => {
            const key = normalizeName([...pfx, k].join('.'));
            if (typeof v === 'string') { const hex = toHex(v); if (hex) put(collect.color, key, hex); }
            else if (typeof v === 'object') flatten(v, [...pfx, k]);
          });
        };
        flatten(colors, ['color']);
      }
      const spacing = t?.spacing || t?.space || t?.sizes;
      if (spacing && typeof spacing === 'object') {
        Object.entries(spacing).forEach(([k, v]) => {
          const val = String(v);
          if (isPxNumber(val) || isRemEm(val)) put(collect.sizeSpacing, normalizeName(`spacing-${k}`), val);
        });
      }
      const radii = t?.borderRadius;
      if (radii && typeof radii === 'object') {
        Object.entries(radii).forEach(([k, v]) => {
          const val = String(v);
          if (isPxNumber(val) || isRemEm(val)) put(collect.sizeRadius, normalizeName(`radius-${k}`), val);
        });
      }
      const fontSize = t?.fontSize;
      if (fontSize && typeof fontSize === 'object') {
        Object.entries(fontSize).forEach(([k, v]) => {
          const val = Array.isArray(v) ? String(v[0]) : String(v);
          if (isPxNumber(val) || isRemEm(val)) put(collect.sizeFont, normalizeName(`font-${k}`), val);
        });
      }
      const fonts = t?.fontFamily;
      if (fonts && typeof fonts === 'object') {
        Object.entries(fonts).forEach(([k, v]) => {
          const fam = Array.isArray(v) ? v.join(', ') : String(v);
          put(collect.fontFamily, normalizeName(`font-${k}`), fam.replace(/["']/g, ''));
        });
      }
      const screens = t?.screens;
      if (screens && typeof screens === 'object') {
        Object.entries(screens).forEach(([k, v]) => {
          const px = String(v).endsWith('px') ? v : /^\d+$/.test(String(v)) ? `${v}px` : null;
          if (px) put(collect.sizeBreakpoint, normalizeName(`bp-${k}`), px);
        });
      }
    } catch { /* optional */ }
  }

  // Build DTCG token JSON
  const objFromMap = (m, type) =>
    Object.fromEntries([...m.entries()].map(([k, v]) => [k, { $type: type, $value: v }]));

  const tokens = {
    $schema: "https://www.designtokens.org/schemas/aliases.json",
    color: objFromMap(collect.color, "color"),
    size: {
      spacing: objFromMap(collect.sizeSpacing, "dimension"),
      radius: objFromMap(collect.sizeRadius, "dimension"),
      font: objFromMap(collect.sizeFont, "dimension"),
      line: objFromMap(collect.sizeLine, "dimension"),
      breakpoint: objFromMap(collect.sizeBreakpoint, "dimension"),
    },
    shadow: objFromMap(collect.shadow, "shadow"),
    z: objFromMap(collect.zIndex, "number"),
    opacity: objFromMap(collect.opacity, "number"),
    font: { family: objFromMap(collect.fontFamily, "fontFamily") },
  };

  const out = path.join(OUT_DIR, 'primitives.json');
  fs.writeFileSync(out, JSON.stringify(tokens, null, 2));
  
  // Summary
  const counts = {
    color: collect.color.size,
    spacing: collect.sizeSpacing.size,
    radius: collect.sizeRadius.size,
    font: collect.sizeFont.size,
    shadow: collect.shadow.size,
    fontFamily: collect.fontFamily.size,
  };
  
  console.log(`\n🎨 Extracted tokens:`);
  console.log(`   Colors: ${counts.color}`);
  console.log(`   Spacing: ${counts.spacing}`);
  console.log(`   Radius: ${counts.radius}`);
  console.log(`   Fonts: ${counts.font}`);
  console.log(`   Shadows: ${counts.shadow}`);
  console.log(`   Font Families: ${counts.fontFamily}`);
  console.log(`\n✅ Wrote ${out}`);
}

main().catch(e => { console.error(e); process.exit(1); });