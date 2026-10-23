// UBON FLOOD ESCAPE — procedural "hand-drawn" SVG asset generator.
// Run from the project root:  node tools/art/generate_art.mjs
// Every asset is a separate SVG that shares one palette, one ink outline and
// one wobbly-line helper, so the whole game keeps a single consistent style.
// Replace any SVG with a painted PNG of the same size later — scenes only
// reference the file path, and furniture/items read their size at runtime.

import { writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "..");

// ---------------------------------------------------------------- style guide
export const P = {
  ink: "#211e1b",
  mustard: "#c99a3b", mustardL: "#dcb65a", mustardD: "#98722a",
  olive: "#6d7438", oliveL: "#8b9352", oliveD: "#4b5126",
  brown: "#7a4a2b", brownL: "#9d663c", brownD: "#55321d",
  beige: "#cdbb93", beigeL: "#e3d4ae", beigeD: "#a8946c",
  blue: "#6e8b9c", blueL: "#97b1be", blueD: "#4c6575",
  flood: "#3c7a74", floodL: "#5f9c90", floodD: "#285754",
  char: "#2b2926", charL: "#3e3a35",
  cream: "#efe2bf", white: "#e7e2d4", red: "#b0442f", redL: "#c9604a", redD: "#7f2e1f",
  skin: "#c98e62", skinD: "#a6704a", hair: "#1c1918",
  metal: "#a3a9a5", metalD: "#6d7471", gold: "#d8a93a",
};
const OUTLINE = 3;
const BASE_PAD = 6; // every floor-standing sprite has its front-bottom edge 6px above the image bottom

// --------------------------------------------------------------- tiny toolkit
let seed = 7;
const rnd = () => ((seed = (seed * 16807) % 2147483647) - 1) / 2147483646;
const jit = (a) => (rnd() * 2 - 1) * a;
const f = (n) => (Math.round(n * 10) / 10).toString();

function pathFrom(pts, closed = true, w = 0.9) {
  const out = [];
  const n = pts.length;
  const last = closed ? n : n - 1;
  for (let i = 0; i < last; i++) {
    const a = pts[i], b = pts[(i + 1) % n];
    const len = Math.hypot(b[0] - a[0], b[1] - a[1]);
    const steps = Math.max(1, Math.round(len / 14));
    for (let k = 0; k < steps; k++) {
      const t = k / steps;
      let x = a[0] + (b[0] - a[0]) * t, y = a[1] + (b[1] - a[1]) * t;
      if (k > 0) { x += jit(w); y += jit(w); }
      out.push([x, y]);
    }
  }
  if (!closed) out.push(pts[n - 1]);
  return "M" + out.map((p) => f(p[0]) + " " + f(p[1])).join(" L") + (closed ? " Z" : "");
}
function attrs(fill, o) {
  const stroke = o.stroke ?? P.ink;
  let s = ` fill="${fill}" stroke="${stroke}" stroke-width="${o.sw ?? OUTLINE}" stroke-linejoin="round" stroke-linecap="round"`;
  if (o.op != null) s += ` opacity="${o.op}"`;
  return s;
}
const shape = (pts, fill, o = {}) => `<path d="${pathFrom(pts, true, o.w ?? 0.9)}"${attrs(fill, o)}/>`;
const line = (pts, o = {}) => `<path d="${pathFrom(pts, false, o.w ?? 0.6)}"${attrs("none", o)}/>`;
const R = (x, y, w, h, fill, o = {}) => shape([[x, y], [x + w, y], [x + w, y + h], [x, y + h]], fill, o);
const fillR = (x, y, w, h, fill, op = 1) => `<rect x="${f(x)}" y="${f(y)}" width="${f(w)}" height="${f(h)}" fill="${fill}" opacity="${op}"/>`;
function E(cx, cy, rx, ry, fill, o = {}) {
  const n = Math.max(12, Math.round((rx + ry) / 2.5));
  const pts = [];
  const w = o.w ?? 0.6;
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2;
    pts.push([cx + Math.cos(a) * rx + jit(w), cy + Math.sin(a) * ry + jit(w)]);
  }
  return `<path d="M${pts.map((p) => f(p[0]) + " " + f(p[1])).join(" L")} Z"${attrs(fill, o)}/>`;
}
const shadow = (cx, cy, rx, ry, op = 0.3) => `<ellipse cx="${f(cx)}" cy="${f(cy)}" rx="${f(rx)}" ry="${f(ry)}" fill="#120f0c" opacity="${op}"/>`;
const shade = (x, y, w, h, op = 0.22, c = "#000") => fillR(x, y, w, h, c, op);
function grime(x, y, w, h, n, color, op) {
  let s = "";
  for (let i = 0; i < n; i++) s += `<ellipse cx="${f(x + rnd() * w)}" cy="${f(y + rnd() * h)}" rx="${f(1 + rnd() * 3)}" ry="${f(0.8 + rnd() * 2)}" fill="${color}" opacity="${op}"/>`;
  return s;
}
function hatch(x, y, w, h, n, o = {}) {
  let s = "";
  for (let i = 0; i < n; i++) {
    const px = x + rnd() * w, py = y + rnd() * h;
    s += line([[px, py], [px + 4 + rnd() * 3, py - 3 - rnd() * 2]], { sw: o.sw ?? 1.2, stroke: o.color ?? P.ink, op: o.op ?? 0.35, w: 0.2 });
  }
  return s;
}
function box3(x, y, w, d, h, top, front, o = {}) {
  let s = R(x, y, w, d, top) + R(x, y + d, w, h, front);
  s += shade(x + 2, y + d + h - 6, w - 4, 4, 0.2);
  s += line([[x + 4, y + 3], [x + w - 4, y + 3]], { stroke: P.cream, sw: 1.5, op: 0.45 });
  if (o.grain) s += hatch(x + 4, y + d + 4, w - 12, h - 8, Math.round(w / 12), { op: 0.18 });
  return s;
}
const svg = (w, h, body, defs = "") =>
  `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${defs ? `<defs>${defs}</defs>` : ""}${body}</svg>\n`;
let count = 0;
function save(rel, content) {
  const p = join(ROOT, "assets", rel);
  mkdirSync(dirname(p), { recursive: true });
  writeFileSync(p, content);
  count++;
}
// floor-standing furniture: front-bottom edge sits at h - BASE_PAD
function furniture(name, w, h, body) {
  seed = 1000 + name.length * 97 + w * 3 + h;
  save(`environments/furniture/${name}.svg`, svg(w, h, body));
}

// ----------------------------------------------------------------- floor tiles
// Atlas: 5 columns (living, bedroom, kitchen, storage, porch) x 2 variants. Tile = 64x48.
function floorAtlas() {
  seed = 42;
  const TW = 64, TH = 48;
  let s = "";
  for (let v = 0; v < 2; v++) {
    for (let c = 0; c < 5; c++) {
      const ox = c * TW, oy = v * TH;
      if (c === 0) { // old ceramic tiles
        for (let i = 0; i < 2; i++) for (let j = 0; j < 2; j++) {
          const tone = [P.beigeL, "#d9c9a1", "#dccca6"][Math.floor(rnd() * 3)];
          s += fillR(ox + i * 32, oy + j * 24, 32, 24, tone);
          s += fillR(ox + i * 32 + 2, oy + j * 24 + 2, 28, 3, "#fff", 0.12);
        }
        s += grime(ox + 3, oy + 3, 58, 42, 6, P.beigeD, 0.35);
        s += fillR(ox, oy, TW, 1.5, "#8a7a58", 0.8) + fillR(ox, oy + 24, TW, 1.5, "#8a7a58", 0.8);
        s += fillR(ox, oy, 1.5, TH, "#8a7a58", 0.8) + fillR(ox + 32, oy, 1.5, TH, "#8a7a58", 0.8);
        if (v === 1) s += line([[ox + 8, oy + 30], [ox + 15, oy + 36], [ox + 13, oy + 44]], { sw: 1, op: 0.45 });
      } else if (c === 1) { // warm wooden planks
        for (let k = 0; k < 4; k++) {
          const tone = [P.brownL, "#94603a", "#a46d42"][Math.floor(rnd() * 3)];
          s += fillR(ox, oy + k * 12, TW, 12, tone);
          s += fillR(ox, oy + k * 12 + 10.5, TW, 1.5, P.brownD, 0.8);
          const seam = ((k * 23 + v * 17) % 52) + 6;
          s += fillR(ox + seam, oy + k * 12, 1.5, 12, P.brownD, 0.7);
          s += line([[ox + 4 + rnd() * 20, oy + k * 12 + 5], [ox + 34 + rnd() * 20, oy + k * 12 + 6]], { sw: 0.8, stroke: P.brownD, op: 0.35 });
        }
      } else if (c === 2) { // kitchen checker
        for (let i = 0; i < 4; i++) for (let j = 0; j < 4; j++) {
          s += fillR(ox + i * 16, oy + j * 12, 16, 12, (i + j) % 2 ? "#d8cfae" : "#8f9a66");
        }
        s += grime(ox + 2, oy + 2, 60, 44, 5, P.oliveD, 0.25);
        for (let i = 0; i <= 4; i++) s += fillR(ox + i * 16, oy, 1, TH, "#4b4a3a", 0.35);
        for (let j = 0; j <= 4; j++) s += fillR(ox, oy + j * 12, TW, 1, "#4b4a3a", 0.35);
      } else if (c === 3) { // storage concrete
        s += fillR(ox, oy, TW, TH, v ? "#a49a86" : "#aaa08b");
        s += grime(ox + 2, oy + 2, 60, 44, 14, "#6f6757", 0.3);
        s += grime(ox + 2, oy + 2, 60, 44, 6, "#d4cab3", 0.3);
        if (v === 0) s += line([[ox + 10, oy + 6], [ox + 22, oy + 18], [ox + 20, oy + 30]], { sw: 1, op: 0.4 });
        s += fillR(ox, oy, TW, 1, "#5f574a", 0.4) + fillR(ox, oy, 1, TH, "#5f574a", 0.4);
      } else { // weathered porch planks (vertical)
        for (let k = 0; k < 4; k++) {
          const tone = ["#6f5137", "#5f452e", "#76583b"][Math.floor(rnd() * 3)];
          s += fillR(ox + k * 16, oy, 16, TH, tone);
          s += fillR(ox + k * 16 + 14.5, oy, 1.5, TH, "#2d2118", 0.9);
          s += line([[ox + k * 16 + 6, oy + 4 + rnd() * 8], [ox + k * 16 + 7, oy + 30 + rnd() * 10]], { sw: 0.8, stroke: "#2d2118", op: 0.4 });
        }
        s += fillR(ox, oy, TW, TH, P.flood, 0.12); // damp sheen
      }
    }
  }
  save("environments/floor_atlas.svg", svg(TW * 5, TH * 2, s));
}

// ----------------------------------------------------------------------- walls
function walls() {
  seed = 99;
  // Tall back wall (exterior, north). 64x128, tiles horizontally.
  const grad = `<linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${P.mustardL}"/><stop offset="0.75" stop-color="${P.mustard}"/><stop offset="1" stop-color="${P.mustardD}"/></linearGradient>`;
  let s = fillR(0, 0, 64, 128, "url(#g)");
  s += grime(4, 18, 56, 70, 10, P.mustardD, 0.35);
  s += `<path d="M0 84 Q 16 80 32 86 T 64 84 L64 98 L0 98 Z" fill="${P.oliveD}" opacity="0.28"/>`; // old flood line stain
  s += fillR(0, 98, 64, 26, "#7d6331") + fillR(0, 98, 64, 2, P.ink) + fillR(0, 104, 64, 1.2, P.ink, 0.35);
  s += fillR(0, 124, 64, 4, P.ink);
  s += fillR(0, 0, 64, 10, P.brownD) + fillR(0, 10, 64, 2.5, P.ink);
  s += hatch(4, 16, 56, 70, 5, { op: 0.15 });
  save("environments/walls/back_wall.svg", svg(64, 128, s, grad));

  // Cutaway horizontal wall: 16px top cap + 20px face. 64x36, tiles horizontally.
  s = fillR(0, 0, 64, 16, P.beigeL) + fillR(0, 0, 64, 2.5, P.ink) + fillR(0, 14, 64, 2.5, P.ink);
  s += grime(2, 3, 60, 10, 5, P.beigeD, 0.5);
  s += fillR(0, 16, 64, 20, P.mustard) + fillR(0, 28, 64, 8, P.mustardD) + fillR(0, 33.5, 64, 2.5, P.ink);
  s += grime(2, 18, 60, 10, 4, P.mustardD, 0.5);
  save("environments/walls/wall_cut_h.svg", svg(64, 36, s));

  // Cutaway vertical wall: just the top cap seen from above. 16x48, tiles vertically.
  s = fillR(0, 0, 16, 48, P.beigeL) + fillR(0, 0, 2.5, 48, P.ink) + fillR(13.5, 0, 2.5, 48, P.ink);
  s += grime(3, 2, 10, 44, 4, P.beigeD, 0.5);
  save("environments/walls/wall_cut_v.svg", svg(16, 48, s));

  // Wall post (corners / doorway ends) 20x40: cap + face, front-bottom edge at y=36.
  s = R(2, 2, 16, 16, P.beigeL, { sw: 2.5 }) + R(2, 18, 16, 18, P.mustardD, { sw: 2.5 });
  save("environments/walls/wall_post.svg", svg(20, 40, s));
}

// ------------------------------------------------------------- wall decoration
function wallDecor() {
  seed = 5;
  // Window with a view of the rising flood outside
  let s = R(4, 4, 96, 70, P.brownD);
  s += fillR(10, 10, 84, 26, "#6f8592") + fillR(10, 30, 84, 6, "#8aa0a6", 0.6);
  s += `<path d="M10 36 L94 36 L94 64 L10 64 Z" fill="${P.flood}"/>`;
  s += line([[12, 40], [30, 39], [48, 41]], { stroke: P.floodL, sw: 1.5 }) + line([[52, 48], [80, 47]], { stroke: P.floodL, sw: 1.5 });
  s += R(64, 28, 3, 12, P.brownD, { sw: 1.5 }) + R(74, 30, 3, 10, P.brownD, { sw: 1.5 }) + R(84, 29, 3, 11, P.brownD, { sw: 1.5 });
  s += line([[60, 32], [92, 32]], { stroke: P.brownD, sw: 2 });
  s += E(26, 28, 9, 7, P.oliveD, { sw: 1.5 }) + R(25, 30, 2, 7, P.brownD, { sw: 1 });
  for (let i = 0; i < 9; i++) { const x = 14 + rnd() * 76, y = 12 + rnd() * 44; s += line([[x, y], [x - 2, y + 7]], { stroke: "#cfe0e4", sw: 1, op: 0.6 }); }
  s += R(50, 8, 4, 58, P.brown, { sw: 2 }) + R(8, 34, 88, 4, P.brown, { sw: 2 });
  s += R(4, 4, 96, 70, "none", { sw: 3.5 });
  s += shape([[2, 4], [20, 4], [16, 40], [22, 72], [2, 72]], P.olive, { sw: 2.5 }) + shape([[102, 4], [84, 4], [88, 40], [82, 72], [102, 72]], P.olive, { sw: 2.5 });
  s += shade(2, 4, 8, 68, 0.2) + shade(94, 4, 8, 68, 0.2);
  s += R(0, 72, 104, 8, P.brownL);
  save("environments/decor/window.svg", svg(104, 84, s));

  // Painting: Ubon's white square stupa (Wat Phra That Nong Bua) at dusk
  s = R(3, 3, 74, 58, P.brown, { sw: 3 }) + fillR(9, 9, 62, 46, "#e0a25a") + fillR(9, 9, 62, 18, "#8c6a8a", 0.6);
  s += shape([[30, 54], [50, 54], [48, 40], [32, 40]], P.white, { sw: 1.5 }) + shape([[33, 40], [47, 40], [45, 30], [35, 30]], P.white, { sw: 1.5 });
  s += shape([[36, 30], [44, 30], [40, 14]], P.gold, { sw: 1.5 }) + fillR(9, 50, 62, 5, P.oliveD);
  save("environments/decor/picture_stupa.svg", svg(80, 64, s));

  // Painting: Candle Festival wax float
  s = R(3, 3, 62, 50, P.brownD, { sw: 3 }) + fillR(9, 9, 50, 38, "#3b4a63");
  s += shape([[14, 44], [54, 44], [50, 34], [18, 34]], P.gold, { sw: 1.5 }) + shape([[28, 34], [40, 34], [36, 16], [32, 16]], P.mustardL, { sw: 1.5 });
  s += E(34, 13, 2.5, 4, "#f4d27a", { sw: 1 }) + hatch(16, 36, 34, 6, 5, { color: P.brownD, op: 0.5 });
  save("environments/decor/picture_candle.svg", svg(68, 56, s));

  // Calendar
  s = R(3, 6, 38, 48, P.white, { sw: 2.5 }) + fillR(5, 8, 34, 10, P.red) + E(22, 5, 3, 3, P.metal, { sw: 1.5 });
  for (let i = 0; i < 4; i++) for (let j = 0; j < 5; j++) s += fillR(7 + j * 6.5, 22 + i * 7, 4, 4, i === 2 && j === 3 ? P.red : P.charL, 0.7);
  save("environments/decor/calendar.svg", svg(44, 58, s));

  // Family photo
  s = R(3, 3, 40, 32, P.gold, { sw: 2.5 }) + fillR(8, 8, 30, 22, "#97a6a0");
  s += E(16, 18, 4, 4, P.skin, { sw: 1 }) + E(26, 17, 4, 4, P.skin, { sw: 1 }) + E(33, 21, 3, 3, P.skin, { sw: 1 });
  s += fillR(10, 22, 28, 8, P.blueD);
  save("environments/decor/photo.svg", svg(46, 38, s));

  // Wall clock
  s = E(20, 20, 16, 16, P.cream, { sw: 3 }) + line([[20, 20], [20, 9]], { sw: 2 }) + line([[20, 20], [27, 24]], { sw: 2 });
  for (let i = 0; i < 12; i++) { const a = (i / 12) * Math.PI * 2; s += fillR(19.3 + Math.cos(a) * 12, 19.3 + Math.sin(a) * 12, 1.4, 1.4, P.ink); }
  save("environments/decor/clock.svg", svg(40, 40, s));

  // Buddha shelf (หิ้งพระ) on the wall
  s = R(4, 34, 82, 10, P.brownL) + shape([[10, 44], [18, 44], [14, 56]], P.brownD, { sw: 2 }) + shape([[72, 44], [80, 44], [76, 56]], P.brownD, { sw: 2 });
  s += shape([[36, 34], [54, 34], [52, 22], [38, 22]], P.gold, { sw: 2 }) + E(45, 17, 5, 6, P.gold, { sw: 2 }) + shape([[43, 11], [47, 11], [45, 4]], P.gold, { sw: 1.5 });
  s += R(16, 24, 8, 10, P.white, { sw: 1.5 }) + R(66, 24, 8, 10, P.white, { sw: 1.5 }) + E(20, 22, 2, 3, "#f0c060", { sw: 1 }) + E(70, 22, 2, 3, "#f0c060", { sw: 1 });
  s += E(30, 31, 4, 3, "#e7a3b8", { sw: 1.2 }) + E(60, 31, 4, 3, "#f1e3a0", { sw: 1.2 });
  save("environments/decor/buddha_shelf.svg", svg(90, 60, s));
}

// ------------------------------------------------------------------- furniture
function allFurniture() {
  // Bed (head against the back wall) 124x190
  let s = shadow(62, 184, 60, 8);
  s += R(4, 4, 116, 44, P.brownD) + R(12, 10, 100, 30, P.brown, { sw: 2 }) + hatch(16, 14, 90, 22, 8, { op: 0.25 });
  s += box3(6, 34, 112, 140, 10, P.brownL, P.brownD);
  s += R(10, 32, 104, 128, P.white) + R(18, 38, 88, 26, P.cream) + line([[30, 50], [50, 48]], { sw: 1.5, op: 0.4 });
  s += shape([[8, 82], [116, 82], [118, 162], [6, 162]], P.blue) + shade(8, 82, 110, 10, 0.12, "#fff");
  s += line([[20, 100], [44, 120], [40, 150]], { sw: 1.5, op: 0.45 }) + line([[80, 96], [96, 130]], { sw: 1.5, op: 0.45 });
  s += shade(6, 150, 112, 12, 0.18);
  furniture("bed", 124, 190, s);

  // Wardrobe 116x176
  s = shadow(58, 170, 58, 7) + box3(4, 4, 108, 20, 146, P.brownL, P.brown, { grain: true });
  s += R(10, 30, 46, 132, P.brown, { sw: 2 }) + R(60, 30, 46, 132, P.brown, { sw: 2 });
  s += R(64, 36, 38, 60, P.blueL, { sw: 2 }) + line([[70, 44], [80, 60]], { stroke: "#fff", sw: 2, op: 0.5 });
  s += R(50, 88, 4, 14, P.gold, { sw: 1.5 }) + R(62, 88, 4, 14, P.gold, { sw: 1.5 }) + shade(4, 24, 108, 8, 0.25);
  furniture("wardrobe", 116, 176, s);

  // Dresser with drawers (one ajar) 128x96
  s = shadow(64, 90, 62, 6) + box3(4, 12, 120, 26, 52, P.brownL, P.brown, { grain: true });
  s += R(10, 42, 52, 18, P.brownL, { sw: 2 }) + R(66, 42, 52, 18, P.brownL, { sw: 2 }) + R(10, 64, 108, 18, P.brownL, { sw: 2 });
  s += R(32, 49, 10, 4, P.gold, { sw: 1.2 }) + R(88, 49, 10, 4, P.gold, { sw: 1.2 }) + R(60, 71, 10, 4, P.gold, { sw: 1.2 });
  s += R(18, 2, 30, 16, P.metal, { sw: 2 }) + E(100, 14, 8, 5, P.cream, { sw: 2 });
  furniture("dresser", 128, 96, s);

  // Medicine cabinet 72x104
  s = shadow(36, 98, 34, 6) + box3(4, 10, 64, 22, 66, P.white, "#d2cdbf");
  s += R(10, 38, 52, 52, "#dcd7ca", { sw: 2 }) + R(30, 48, 12, 32, P.red, { sw: 1.5 }) + R(20, 58, 32, 12, P.red, { sw: 1.5 });
  s += E(56, 64, 2.5, 2.5, P.metal, { sw: 1.2 });
  furniture("med_cabinet", 72, 104, s);

  // Nightstand 52x66
  s = shadow(26, 60, 24, 5) + box3(4, 10, 44, 18, 32, P.brownL, P.brown) + R(9, 32, 34, 12, P.brownL, { sw: 1.8 });
  s += R(14, 0, 10, 12, "#f0d58a", { sw: 1.8 }) + R(16, 10, 6, 3, P.ink, { sw: 1 });
  furniture("nightstand", 52, 66, s);

  // Standing fan 48x110
  s = shadow(24, 104, 18, 5) + E(24, 100, 16, 6, P.charL) + R(22, 46, 4, 52, P.metalD, { sw: 2 });
  s += E(24, 30, 21, 21, P.blueL) + E(24, 30, 15, 15, "none", { sw: 1.5 });
  for (let i = 0; i < 3; i++) { const a = (i / 3) * Math.PI * 2; s += E(24 + Math.cos(a) * 8, 30 + Math.sin(a) * 8, 6, 4, P.blue, { sw: 1.5 }); }
  s += E(24, 30, 4, 4, P.char, { sw: 1.5 });
  furniture("fan", 48, 110, s);

  // Potted plant 56x90
  s = shadow(28, 84, 20, 5) + shape([[14, 60], [42, 60], [38, 84], [18, 84]], "#a8603e") + fillR(15, 60, 26, 5, "#7c4630", 0.7);
  s += shape([[28, 62], [6, 30], [22, 40]], P.olive) + shape([[28, 62], [50, 26], [36, 42]], P.oliveL) + shape([[28, 62], [24, 4], [36, 30]], P.olive);
  s += shape([[28, 62], [8, 52], [18, 48]], P.oliveD) + line([[28, 60], [24, 10]], { stroke: P.oliveD, sw: 1.2 });
  furniture("plant", 56, 90, s);

  // Rug (floor decal) 200x120
  seed = 3;
  s = shape([[8, 10], [192, 6], [194, 112], [6, 114]], P.redD) + shape([[20, 20], [180, 18], [182, 100], [18, 102]], P.red, { sw: 2 });
  s += shape([[60, 44], [140, 42], [142, 78], [58, 80]], P.mustard, { sw: 2 }) + shape([[100, 50], [118, 61], [100, 72], [82, 61]], P.olive, { sw: 1.5 });
  for (let i = 0; i < 12; i++) s += line([[10 + i * 16, 112], [10 + i * 16, 118]], { sw: 1.5, stroke: P.cream });
  save("environments/furniture/rug.svg", svg(200, 120, s));
  s = shape([[6, 6], [90, 4], [92, 40], [4, 42]], P.oliveD) + hatch(10, 12, 74, 24, 18, { color: P.olive, op: 0.6 });
  save("environments/furniture/doormat.svg", svg(96, 46, s));

  // Kitchen counter with sink 196x104
  s = shadow(98, 98, 96, 6) + box3(4, 8, 188, 40, 50, "#cfc3a2", P.olive, { grain: true });
  for (let i = 1; i < 6; i++) s += fillR(4 + i * 31, 9, 1, 38, P.beigeD, 0.6);
  s += R(26, 14, 66, 28, P.metal) + R(32, 18, 54, 20, P.metalD, { sw: 2 }) + R(54, 2, 6, 16, P.metal, { sw: 2 });
  s += R(10, 52, 56, 42, P.oliveL, { sw: 2 }) + R(70, 52, 56, 42, P.oliveL, { sw: 2 }) + R(130, 52, 56, 42, P.oliveL, { sw: 2 });
  s += R(58, 66, 4, 12, P.metal, { sw: 1.2 }) + R(74, 66, 4, 12, P.metal, { sw: 1.2 }) + R(134, 66, 4, 12, P.metal, { sw: 1.2 });
  s += E(130, 22, 10, 6, P.white, { sw: 2 }) + E(160, 24, 12, 7, P.blueL, { sw: 2 });
  furniture("counter_sink", 196, 104, s);

  // Stove counter 128x104
  s = shadow(64, 98, 62, 6) + box3(4, 8, 120, 40, 50, "#cfc3a2", P.olive, { grain: true });
  s += R(14, 12, 92, 30, P.char) + E(38, 27, 11, 7, P.charL, { sw: 2 }) + E(82, 27, 11, 7, P.charL, { sw: 2 });
  s += E(82, 20, 13, 6, P.metal) + R(69, 10, 26, 12, P.metalD, { sw: 2 }) + line([[95, 14], [110, 10]], { sw: 2.5 });
  s += R(10, 52, 108, 42, P.oliveL, { sw: 2 }) + R(30, 58, 30, 30, P.redD, { sw: 2 });
  furniture("stove_counter", 128, 104, s);

  // Fridge 76x150
  s = shadow(38, 144, 36, 6) + box3(4, 4, 68, 18, 122, "#cbd6d6", P.blueL);
  s += R(8, 26, 60, 34, "#a8bec6", { sw: 2 }) + R(8, 64, 60, 76, "#a8bec6", { sw: 2 });
  s += R(58, 40, 4, 14, P.metal, { sw: 1.5 }) + R(58, 72, 4, 20, P.metal, { sw: 1.5 });
  s += R(18, 76, 14, 10, P.mustardL, { sw: 1.5 }) + E(40, 90, 4, 4, P.red, { sw: 1.5 }) + R(16, 96, 18, 22, P.white, { sw: 1.5 });
  furniture("fridge", 76, 150, s);

  // Food shelf with jars, rice sacks 128x170
  s = shadow(64, 164, 62, 6) + R(4, 4, 120, 160, P.brownD) + fillR(8, 8, 112, 152, "#3b2a1c");
  for (let k = 0; k < 4; k++) s += R(6, 40 + k * 38, 116, 6, P.brownL, { sw: 2 });
  s += R(12, 18, 16, 22, "#e0c79a", { sw: 2 }) + R(32, 22, 16, 18, P.redL, { sw: 2 }) + R(52, 14, 12, 26, P.olive, { sw: 2 }) + R(90, 20, 24, 20, P.cream, { sw: 2 });
  s += E(22, 66, 12, 12, "#d8c7a0") + R(42, 58, 18, 20, P.mustard, { sw: 2 }) + R(64, 54, 12, 24, "#7f9cb0", { sw: 2 }) + R(80, 54, 12, 24, "#7f9cb0", { sw: 2 });
  s += shape([[12, 116], [52, 116], [56, 92], [8, 92]], P.beige) + line([[18, 104], [44, 104]], { sw: 1.5, stroke: P.red });
  s += R(64, 96, 22, 20, P.redD, { sw: 2 }) + R(90, 100, 26, 16, P.brownL, { sw: 2 });
  s += R(14, 132, 40, 22, P.oliveL, { sw: 2 }) + R(62, 136, 50, 18, P.beigeL, { sw: 2 });
  furniture("food_shelf", 128, 170, s);

  // Dining table 160x100
  s = shadow(80, 94, 76, 6) + R(14, 70, 8, 24, P.brownD) + R(138, 70, 8, 24, P.brownD);
  s += box3(6, 8, 148, 56, 10, P.brownL, P.brown, {}) + hatch(14, 14, 130, 44, 10, { op: 0.2 });
  s += E(40, 30, 12, 7, P.white, { sw: 2 }) + E(110, 34, 14, 8, P.cream, { sw: 2 }) + R(70, 20, 16, 18, P.mustard, { sw: 2 });
  furniture("dining_table", 160, 100, s);

  // Chair 44x76
  s = shadow(22, 70, 18, 5) + R(6, 4, 32, 36, P.brown) + R(10, 10, 24, 6, P.brownL, { sw: 1.5 });
  s += box3(4, 36, 36, 16, 6, P.brownL, P.brownD) + R(6, 58, 5, 12, P.brownD, { sw: 2 }) + R(33, 58, 5, 12, P.brownD, { sw: 2 });
  furniture("chair", 44, 76, s);

  // Dragon water jar (โอ่งมังกร) 72x86
  s = shadow(36, 80, 30, 6) + E(36, 50, 30, 30, "#6b3a22") + shade(10, 50, 52, 24, 0.15);
  s += line([[14, 44], [24, 38], [32, 46], [42, 38], [52, 46], [60, 42]], { stroke: P.gold, sw: 3 });
  s += E(36, 22, 24, 7, P.brownL) + E(36, 20, 20, 5, P.brownD, { sw: 2 }) + E(26, 46, 4, 8, "#fff", { stroke: "none", op: 0.2 });
  furniture("water_jar", 72, 86, s);

  // Red sofa 176x104
  s = shadow(88, 98, 86, 7) + R(10, 4, 156, 44, P.redD) + R(18, 10, 66, 34, P.red, { sw: 2 }) + R(92, 10, 66, 34, P.red, { sw: 2 });
  s += R(18, 44, 140, 28, P.redL) + line([[88, 46], [88, 70]], { sw: 2 });
  s += box3(2, 30, 24, 40, 28, P.redL, P.redD) + box3(150, 30, 24, 40, 28, P.redL, P.redD);
  s += R(26, 72, 124, 26, P.redD) + R(120, 16, 30, 22, P.cream, { sw: 2 });
  furniture("sofa", 176, 104, s);

  // Coffee table 116x66
  s = shadow(58, 60, 54, 5) + R(10, 40, 7, 20, P.brownD, { sw: 2 }) + R(99, 40, 7, 20, P.brownD, { sw: 2 });
  s += box3(4, 8, 108, 30, 10, P.brownL, P.brown) + E(92, 20, 7, 4, P.white, { sw: 1.5 });
  furniture("coffee_table", 116, 66, s);

  // TV cabinet with a CRT TV 140x140
  s = shadow(70, 134, 68, 6) + box3(4, 80, 132, 24, 30, P.brownL, P.brown, { grain: true });
  s += R(10, 108, 56, 22, P.brownD, { sw: 2 }) + R(74, 108, 56, 22, P.brownD, { sw: 2 });
  s += R(26, 14, 88, 70, P.charL) + R(34, 20, 64, 52, "#4d5b5e", { sw: 2.5 }) + line([[42, 28], [54, 40]], { stroke: "#9fb3b0", sw: 2, op: 0.6 });
  s += E(106, 34, 4, 4, P.metal, { sw: 1.5 }) + E(106, 48, 4, 4, P.metal, { sw: 1.5 }) + line([[60, 14], [46, 0]], { sw: 2 }) + line([[78, 14], [96, 2]], { sw: 2 });
  furniture("tv_stand", 140, 140, s);

  // Shoe rack 80x58
  s = shadow(40, 52, 38, 5) + box3(4, 8, 72, 14, 30, P.brownL, P.brownD);
  s += E(20, 32, 9, 4, P.white, { sw: 1.5 }) + E(42, 34, 9, 4, P.redD, { sw: 1.5 }) + E(62, 32, 8, 4, P.blueD, { sw: 1.5 });
  furniture("shoe_rack", 80, 58, s);

  // Document cabinet (ตู้เอกสาร) 100x100
  s = shadow(50, 94, 48, 6) + box3(4, 8, 92, 22, 64, "#9fa58a", "#7f876a");
  for (let k = 0; k < 3; k++) s += R(10, 34 + k * 20, 80, 16, "#8f9878", { sw: 2 }) + R(42, 39 + k * 20, 16, 5, P.metal, { sw: 1.2 });
  s += R(64, 0, 26, 14, P.cream, { sw: 2 }) + R(14, 4, 20, 10, P.blueL, { sw: 2 });
  furniture("doc_cabinet", 100, 100, s);

  // Metal storage rack with boxes 156x170
  s = shadow(78, 164, 74, 6) + R(6, 4, 6, 160, P.metalD, { sw: 2 }) + R(144, 4, 6, 160, P.metalD, { sw: 2 });
  for (let k = 0; k < 4; k++) s += R(4, 30 + k * 40, 148, 6, P.metal, { sw: 2 });
  s += R(16, 6, 40, 24, P.beige) + R(60, 10, 30, 20, P.redD) + R(100, 2, 40, 28, P.beigeD);
  s += R(16, 48, 50, 22, "#c4a974") + R(74, 44, 34, 26, P.blueD) + line([[22, 58], [40, 58]], { sw: 1.5 });
  s += R(18, 86, 30, 24, P.oliveL) + R(54, 92, 40, 18, P.beigeL) + R(104, 84, 34, 26, "#c4a974");
  s += R(20, 128, 56, 22, P.beige) + R(90, 132, 40, 18, P.char);
  furniture("metal_rack", 156, 170, s);

  // Wooden crate 76x80
  s = shadow(38, 74, 34, 5) + box3(4, 6, 68, 20, 48, P.brownL, P.brown);
  s += line([[8, 30], [68, 70]], { sw: 3, stroke: P.brownD }) + line([[8, 50], [68, 50]], { sw: 2 }) + hatch(10, 30, 50, 36, 4, { op: 0.2 });
  furniture("crate", 76, 80, s);

  // Stack of cardboard boxes 92x124
  s = shadow(46, 118, 42, 6) + box3(6, 56, 80, 22, 40, "#d3b783", "#b8955e") + box3(14, 20, 62, 18, 38, "#d3b783", "#b8955e");
  s += line([[46, 56], [46, 78]], { sw: 2, stroke: "#8a6a3a" }) + line([[44, 20], [44, 38]], { sw: 2, stroke: "#8a6a3a" }) + R(24, 48, 16, 8, P.white, { sw: 1.5 });
  furniture("boxes", 92, 124, s);

  // Workbench with tools 168x104
  s = shadow(84, 98, 82, 6) + R(10, 58, 8, 40, P.brownD) + R(150, 58, 8, 40, P.brownD) + R(14, 80, 140, 6, P.brown, { sw: 2 });
  s += box3(4, 20, 160, 30, 10, P.brownL, P.brown) + R(20, 4, 48, 22, P.red) + R(34, 0, 20, 6, P.char, { sw: 2 });
  s += line([[96, 30], [124, 40]], { sw: 3, stroke: P.metalD }) + R(120, 34, 10, 8, P.char, { sw: 1.5 }) + E(146, 34, 8, 4, P.mustard, { sw: 1.5 });
  furniture("workbench", 168, 104, s);

  // Blue plastic barrel 64x96
  s = shadow(32, 90, 28, 6) + R(6, 16, 52, 74, P.blueD) + E(32, 16, 26, 8, P.blue) + E(32, 16, 10, 3, P.blueD, { sw: 1.5 });
  s += line([[6, 40], [58, 40]], { sw: 2 }) + line([[6, 68], [58, 68]], { sw: 2 }) + fillR(14, 20, 6, 66, "#fff", 0.15);
  furniture("barrel", 64, 96, s);

  // Bucket + broom (decor) 64x96
  s = shadow(26, 90, 20, 5) + line([[46, 4], [54, 70]], { sw: 4, stroke: P.brown }) + shape([[44, 66], [62, 64], [64, 90], [44, 90]], P.mustardL, { sw: 2 });
  s += shape([[8, 58], [44, 58], [40, 90], [12, 90]], P.redL) + E(26, 58, 18, 5, P.redD, { sw: 2 });
  furniture("bucket_broom", 64, 96, s);

  // Armchair 84x92
  s = shadow(42, 86, 40, 6) + R(8, 4, 68, 40, P.oliveD) + R(14, 40, 56, 22, P.olive);
  s += box3(2, 30, 14, 34, 22, P.oliveL, P.oliveD) + box3(68, 30, 14, 34, 22, P.oliveL, P.oliveD) + R(16, 62, 52, 24, P.oliveD);
  furniture("armchair", 84, 92, s);
}

// ------------------------------------------------------- outside the house
function outside() {
  seed = 77;
  // Banana tree rising out of floodwater 160x220 (waterline at the bottom)
  let s = E(80, 212, 26, 6, P.floodD, { sw: 2 }) + shape([[72, 214], [88, 214], [86, 90], [76, 90]], P.oliveD);
  const leaf = (pts, c) => shape(pts, c, { sw: 2.5 }) + line([pts[0], pts[2]], { stroke: P.oliveD, sw: 1.5 });
  s += leaf([[80, 96], [6, 70], [30, 40], [60, 70]], P.olive) + leaf([[82, 96], [156, 64], [128, 36], [100, 70]], P.oliveL);
  s += leaf([[80, 92], [40, 10], [70, 6], [84, 60]], P.oliveL) + leaf([[82, 92], [120, 8], [140, 30], [96, 66]], P.olive);
  s += leaf([[80, 100], [20, 130], [10, 110], [50, 96]], P.oliveD) + E(92, 120, 7, 10, "#6a3b3b", { sw: 2 });
  s += line([[60, 205], [100, 206]], { stroke: P.floodL, sw: 2 });
  save("environments/outside/banana_tree.svg", svg(160, 220, s));

  // Long-tail wooden boat tied at the porch 220x92
  s = shadow(110, 78, 100, 10, 0.25) + shape([[6, 44], [40, 66], [190, 66], [216, 36], [190, 48], [30, 48]], P.brownD);
  s += shape([[30, 48], [190, 48], [180, 58], [40, 58]], "#3b2618", { sw: 2 }) + R(70, 46, 8, 14, P.brownL, { sw: 2 }) + R(130, 46, 8, 14, P.brownL, { sw: 2 });
  s += line([[40, 54], [180, 54]], { stroke: P.mustard, sw: 2 }) + line([[214, 36], [236, 10]], { sw: 2, stroke: P.beigeD });
  s += line([[20, 74], [60, 76], [100, 74]], { stroke: P.floodL, sw: 2 }) + line([[130, 76], [190, 74]], { stroke: P.floodL, sw: 2 });
  save("environments/outside/boat.svg", svg(240, 92, s));

  // Utility pole poking out of the water 60x280
  s = E(30, 272, 16, 4, P.floodD, { sw: 2 }) + R(24, 10, 12, 262, "#7c7a72") + R(6, 26, 48, 6, P.brownD, { sw: 2 }) + R(10, 46, 40, 5, P.brownD, { sw: 2 });
  s += E(12, 22, 4, 4, P.white, { sw: 1.5 }) + E(48, 22, 4, 4, P.white, { sw: 1.5 }) + R(16, 84, 28, 22, P.metalD, { sw: 2 }) + fillR(26, 120, 4, 140, "#000", 0.15);
  save("environments/outside/pole.svg", svg(60, 280, s));

  // Half-submerged fence 140x64
  s = "";
  for (let i = 0; i < 6; i++) s += shape([[6 + i * 22, 58], [6 + i * 22, 14], [14 + i * 22, 6], [22 + i * 22, 14], [22 + i * 22, 58]], i % 2 ? P.brownL : P.brown, { sw: 2.5 });
  s += R(2, 24, 136, 8, P.brownD, { sw: 2 }) + fillR(0, 46, 140, 18, P.flood, 0.85) + line([[0, 46], [140, 46]], { stroke: P.floodL, sw: 2 });
  save("environments/outside/fence.svg", svg(140, 64, s));

  // Floating debris
  s = E(20, 18, 16, 8, P.redL) + E(20, 15, 12, 4, P.redD, { sw: 1.5 }) + line([[2, 26], [38, 26]], { stroke: P.floodL, sw: 1.5 });
  save("environments/outside/debris_bucket.svg", svg(40, 30, s));
  s = R(4, 6, 70, 12, P.brownL, { sw: 2.5 }) + line([[10, 12], [60, 12]], { stroke: P.brownD, sw: 1 }) + line([[0, 22], [78, 22]], { stroke: P.floodL, sw: 1.5 });
  save("environments/outside/debris_plank.svg", svg(78, 26, s));
  s = E(16, 12, 12, 6, P.blueD) + line([[8, 10], [16, 6], [22, 10]], { stroke: P.cream, sw: 2 });
  save("environments/outside/debris_sandal.svg", svg(32, 22, s));
  // Porch pillar stub sitting in the water 24x60
  s = R(5, 4, 14, 52, P.brownD, { sw: 2.5 }) + fillR(4, 40, 16, 20, P.flood, 0.7) + line([[0, 42], [24, 42]], { stroke: P.floodL, sw: 1.5 });
  save("environments/outside/stilt.svg", svg(24, 60, s));
}

// ------------------------------------------------------------------- items
function items() {
  const icon = (name, body) => { seed = 300 + name.length * 13; save(`items/${name}.svg`, svg(64, 64, shadow(32, 56, 20, 4, 0.25) + body)); };
  icon("water", R(23, 18, 18, 38, "#b9d5dc") + R(27, 10, 10, 9, "#bcd4da", { sw: 2.5 }) + R(26, 4, 12, 7, P.blue, { sw: 2.5 }) +
    R(22, 28, 20, 14, P.blueD, { sw: 2 }) + E(32, 35, 4, 3, P.cream, { sw: 1.2 }) + fillR(26, 20, 3, 34, "#fff", 0.5) + line([[23, 46], [41, 46]], { sw: 1.2, op: 0.4 }));
  icon("canned_food", R(16, 16, 32, 38, P.metal) + R(16, 24, 32, 22, P.redL, { sw: 2 }) + E(32, 16, 16, 5, "#c6ccc8") + E(32, 16, 10, 2.5, "none", { sw: 1.2 }) +
    E(32, 35, 9, 5, P.cream, { sw: 1.5 }) + line([[26, 35], [38, 35]], { stroke: P.redD, sw: 1.5 }) + fillR(20, 26, 3, 18, "#fff", 0.35));
  icon("medicine", R(10, 22, 44, 32, P.red) + R(24, 14, 16, 10, "none", { sw: 3 }) + R(28, 28, 8, 20, P.white, { sw: 1.8 }) + R(22, 34, 20, 8, P.white, { sw: 1.8 }) +
    shade(10, 46, 44, 7, 0.2) + line([[13, 25], [50, 25]], { stroke: "#fff", sw: 1.5, op: 0.4 }));
  icon("flashlight", shape([[8, 34], [38, 24], [42, 36], [12, 46]], P.char) + shape([[38, 18], [52, 14], [58, 34], [44, 40]], P.oliveD) +
    E(55, 24, 4, 10, "#f6e08a", { sw: 2 }) + R(18, 30, 10, 6, P.mustard, { sw: 1.5 }) + line([[14, 38], [36, 31]], { stroke: "#fff", sw: 1.2, op: 0.3 }));
  icon("batteries", R(14, 14, 14, 40, P.char) + R(14, 14, 14, 12, "#c07a3a", { sw: 2 }) + R(18, 9, 6, 5, P.metal, { sw: 1.5 }) +
    R(34, 18, 14, 38, P.char) + R(34, 18, 14, 12, "#c07a3a", { sw: 2 }) + R(38, 13, 6, 5, P.metal, { sw: 1.5 }) + fillR(17, 28, 2, 22, "#fff", 0.3) + fillR(37, 32, 2, 20, "#fff", 0.3));
  icon("rope", E(32, 36, 24, 16, "#b98d52") + E(32, 36, 17, 11, "#a87c45", { sw: 2 }) + E(32, 36, 10, 6, "#8e6638", { sw: 2 }) + E(32, 36, 4, 2, P.ink, { sw: 1.5 }) +
    hatch(12, 26, 40, 20, 10, { op: 0.35 }) + line([[52, 40], [58, 52], [54, 58]], { sw: 3, stroke: "#b98d52" }));
  icon("radio", line([[44, 22], [56, 4]], { sw: 2.5 }) + R(8, 22, 48, 32, P.oliveD) + R(12, 26, 24, 24, P.char, { sw: 2 }) +
    R(40, 28, 12, 8, "#e9d58f", { sw: 1.5 }) + E(46, 44, 5, 5, P.metal, { sw: 1.5 }) + R(22, 16, 20, 7, P.char, { sw: 2 }) +
    line([[16, 32], [32, 32]], { sw: 1, stroke: P.metal }) + line([[16, 38], [32, 38]], { sw: 1, stroke: P.metal }) + line([[16, 44], [32, 44]], { sw: 1, stroke: P.metal }));
  icon("documents", shape([[10, 18], [26, 18], [30, 22], [54, 22], [54, 54], [10, 54]], P.mustardL) + R(16, 10, 30, 32, P.white, { sw: 2 }) + R(20, 14, 30, 32, "#f3efe3", { sw: 2 }) +
    line([[24, 22], [44, 22]], { sw: 1.2, op: 0.5 }) + line([[24, 27], [44, 27]], { sw: 1.2, op: 0.5 }) + line([[24, 32], [38, 32]], { sw: 1.2, op: 0.5 }) +
    E(40, 38, 5, 5, "none", { stroke: P.red, sw: 1.8 }) + shape([[10, 30], [54, 30], [54, 54], [10, 54]], P.mustard) + R(28, 6, 6, 14, P.metal, { sw: 1.5 }));
}

// ----------------------------------------------------------------- character
// 64x96 frames, feet on y = 90 (pivot = bottom-centre at (32, 90)).
// dir: down | up | side (facing right; the game flips it for left).
// o.arms: swing | carry | reach | windup | release | recover
const PC = { shirt: "#e4dfd0", shirtD: "#b7b0a0", shorts: "#2e3440", shoe: "#3a3532", bag: "#34465a", bagD: "#24323f" };

function arm(x, y, w, h, hx, hy) { // sleeve + forearm + hand
  return R(x, y, w, h, P.skin, { sw: 2.5 }) + R(x - 1, y - 3, w + 2, 8, PC.shirt, { sw: 2.2 }) + E(hx, hy, 3.5, 3.5, P.skin, { sw: 2 });
}

function frontArms(dir, mode, b, swing) {
  // arms drawn in front of the torso (down view) — returns [behindTorso, inFront]
  if (dir === "down") {
    switch (mode) {
      case "carry": return ["", R(12, 40 + b, 7, 10, P.skin, { sw: 2.5 }) + R(45, 40 + b, 7, 10, P.skin, { sw: 2.5 }) +
        R(11, 37 + b, 9, 8, PC.shirt, { sw: 2.2 }) + R(44, 37 + b, 9, 8, PC.shirt, { sw: 2.2 }) +
        R(16, 47 + b, 13, 6, P.skin, { sw: 2.5 }) + R(35, 47 + b, 13, 6, P.skin, { sw: 2.5 }) + E(29, 50 + b, 3.5, 3.5, P.skin, { sw: 2 }) + E(35, 50 + b, 3.5, 3.5, P.skin, { sw: 2 })];
      case "reach": return ["", arm(16, 44 + b, 7, 22, 20, 68 + b) + arm(41, 44 + b, 7, 22, 44, 68 + b)];
      case "windup": return [arm(45, 18 + b, 7, 22, 48.5, 17 + b), arm(12, 42 + b, 7, 16, 15.5, 59 + b)];
      case "release": return ["", arm(12, 40 + b - 3, 7, 18, 15.5, 56 + b) + arm(38, 44 + b, 9, 18, 43, 64 + b)];
      default: return ["", arm(12, 40 + b + swing, 7, 18, 15.5, 59 + b + swing) + arm(45, 40 + b - swing, 7, 18, 48.5, 59 + b - swing)];
    }
  }
  // up view: arms that go forward are hidden behind the body
  switch (mode) {
    case "carry": case "reach": case "release":
      return [arm(13, 40 + b, 7, 14, 16, 54 + b) + arm(44, 40 + b, 7, 14, 48, 54 + b), ""];
    case "windup": return ["", arm(45, 16 + b, 7, 24, 48.5, 15 + b) + arm(12, 40 + b, 7, 18, 15.5, 59 + b)];
    default: return [arm(12, 40 + b + swing, 7, 18, 15.5, 59 + b + swing) + arm(45, 40 + b - swing, 7, 18, 48.5, 59 + b - swing), ""];
  }
}

// Side-view leg from the hip: t = thigh angle (deg, + = forward), k = knee bend (deg).
function sideLeg(hx, hy, t, k, far) {
  const r = Math.PI / 180, L = 10.5;
  const kx = hx + Math.sin(t * r) * L, ky = hy + Math.cos(t * r) * L;
  const ax = kx + Math.sin((t - k) * r) * L, ay = ky + Math.cos((t - k) * r) * L;
  const pts = [[hx, hy], [kx, ky], [ax, ay]];
  const foot = (t - k) * r; // shoe follows the shin a little (toe-off / tucked foot)
  const fx = ax + Math.cos(foot) * 3.5, fy = ay + 1.5 - Math.sin(foot) * 1.5;
  return line(pts, { sw: 10, w: 0 }) + line(pts, { stroke: far ? P.skinD : P.skin, sw: 5.2, w: 0 }) +
    E(fx, fy, 6.5, 3.4, far ? "#2a2624" : PC.shoe, { sw: 2.5 });
}

// Side-view swinging arm from the shoulder: a = upper-arm angle (deg, + = forward), el = elbow bend (forward).
function sideSwingArm(sx, sy, a, el, far) {
  const r = Math.PI / 180;
  const ex = sx + Math.sin(a * r) * 9, ey = sy + Math.cos(a * r) * 9;
  const hx = ex + Math.sin((a + el) * r) * 8.5, hy = ey + Math.cos((a + el) * r) * 8.5;
  const pts = [[sx, sy], [ex, ey], [hx, hy]];
  return line(pts, { sw: 9, w: 0 }) + line(pts, { stroke: far ? P.skinD : P.skin, sw: 4.6, w: 0 }) +
    E(hx, hy, 3.4, 3.4, far ? P.skinD : P.skin, { sw: 2 }) +
    line([[sx, sy], [sx + Math.sin(a * r) * 4, sy + Math.cos(a * r) * 4]], { sw: 9.5, w: 0 }) +
    line([[sx, sy], [sx + Math.sin(a * r) * 4, sy + Math.cos(a * r) * 4]], { stroke: far ? PC.shirtD : PC.shirt, sw: 5.5, w: 0 });
}

function sideArm(mode, b, lx, swing, elbow = 10) {
  switch (mode) {
    case "carry": return R(30 + lx, 42 + b, 15, 7, P.skin, { sw: 2.5 }) + R(29 + lx, 38 + b, 9, 7, PC.shirt, { sw: 2.2 }) + E(46 + lx, 46 + b, 3.5, 3.5, P.skin, { sw: 2 });
    case "reach": return arm(36 + lx, 46 + b, 7, 22, 40 + lx, 70 + b);
    case "windup": return arm(20 + lx, 22 + b, 7, 20, 23 + lx, 21 + b);
    case "release": return R(36 + lx, 36 + b, 16, 7, P.skin, { sw: 2.5 }) + R(31 + lx, 37 + b, 9, 8, PC.shirt, { sw: 2.2 }) + E(54 + lx, 39 + b, 3.5, 3.5, P.skin, { sw: 2 });
    case "recover": return arm(34 + lx, 42 + b, 7, 17, 38 + lx, 61 + b);
    default: return sideSwingArm(33 + lx, 41 + b, swing * 5, elbow, false);
  }
}

function playerFrame(dir, o = {}) {
  const { bob = 0, stepL = 0, stepR = 0, swing = 0, arms = "swing", crouch = 0, lean = 0, legs = null, elbow = 10 } = o;
  const b = bob + crouch;
  let s = shadow(32, 90, 15, 4.5, 0.3);
  if (dir === "side") {
    const lx = lean;
    // legs: { near: [thigh, knee], far: [thigh, knee] }; without it, a standing pose from stepL/stepR
    const crouchK = crouch * 4;
    const near = legs ? legs.near : [3 + stepL * 3, crouchK];
    const farL = legs ? legs.far : [-3 - stepR * 3, crouchK + 2];
    const hip = 66 + bob + crouch * 0.3;
    s += sideLeg(32 + lx * 0.5, hip, farL[0], farL[1], true);
    s += sideLeg(32 + lx * 0.5, hip, near[0], near[1], false);
    s += R(23 + lx * 0.5, 56 + b, 20, 14, PC.shorts, { sw: 2.5 });
    if (arms === "swing" && swing !== 0) s += sideSwingArm(31 + lx, 41 + b, -swing * 5, elbow, true);
    s += R(14 + lx, 36 + b, 14, 26, PC.bag) + R(16 + lx, 46 + b, 10, 10, PC.bagD, { sw: 2 });
    s += R(24 + lx, 36 + b, 18, 23, PC.shirt) + shade(24 + lx, 50 + b, 18, 9, 0.15) + line([[26 + lx, 38 + b], [26 + lx, 56 + b]], { stroke: PC.bagD, sw: 3 });
    s += sideArm(arms, b, lx, swing, elbow);
    const h = lx;
    s += E(33 + h, 24 + b, 14, 15, P.skin) + E(46 + h, 27 + b, 2.5, 2, P.skin, { sw: 2 });
    s += shape([[19 + h, 26 + b], [20 + h, 14 + b], [28 + h, 7 + b], [38 + h, 8 + b], [46 + h, 13 + b], [48 + h, 20 + b], [42 + h, 17 + b], [37 + h, 21 + b], [32 + h, 18 + b], [30 + h, 26 + b], [26 + h, 34 + b], [20 + h, 33 + b]], P.hair, { sw: 2.5 });
    s += E(28 + h, 26 + b, 3, 4, P.skinD, { sw: 2 }) + E(41 + h, 25 + b, 1.6, 2.4, P.ink, { stroke: "none" }) + line([[38 + h, 20 + b], [44 + h, 20 + b]], { sw: 2 });
    s += arms === "windup" || arms === "release" ? E(42 + h, 32 + b, 2, 1.6, P.ink, { stroke: "none" }) : line([[40 + h, 32 + b], [44 + h, 32 + b]], { sw: 1.5 });
    return s;
  }
  const up = dir === "up";
  const splay = crouch > 0 ? 2 : 0;
  s += R(23 - splay, 64 + b, 8, 22 + stepL - crouch, P.skin, { sw: 2.5 }) + E(27 - splay, 87 + stepL, 6.5, 3.5, PC.shoe, { sw: 2.5 });
  s += R(33 + splay, 64 + b, 8, 22 + stepR - crouch, P.skin, { sw: 2.5 }) + E(37 + splay, 87 + stepR, 6.5, 3.5, PC.shoe, { sw: 2.5 });
  s += R(21, 56 + b, 22, 13, PC.shorts, { sw: 2.5 }) + fillR(31.5, 60 + b, 1, 9, "#000", 0.4);
  const [behind, front] = frontArms(dir, arms, b, swing);
  s += behind;
  s += R(19, 36 + b, 26, 23, PC.shirt) + shade(19, 50 + b, 26, 9, 0.15);
  if (up) {
    s += R(18, 36 + b, 28, 26, PC.bag) + R(22, 46 + b, 20, 12, PC.bagD, { sw: 2 }) + line([[24, 40 + b], [40, 40 + b]], { stroke: P.mustard, sw: 1.5 });
  } else {
    s += line([[23, 37 + b], [23, 56 + b]], { stroke: PC.bagD, sw: 3.5 }) + line([[41, 37 + b], [41, 56 + b]], { stroke: PC.bagD, sw: 3.5 });
    s += shape([[28, 36 + b], [32, 42 + b], [36, 36 + b]], PC.shirtD, { sw: 2 }) + E(32, 47 + b, 1.2, 1.2, P.ink, { stroke: "none" });
  }
  s += front;
  s += E(32, 24 + b, 15, 15, P.skin) + E(17, 26 + b, 3, 4, P.skin, { sw: 2 }) + E(47, 26 + b, 3, 4, P.skin, { sw: 2 });
  if (up) {
    s += shape([[17, 28 + b], [16, 16 + b], [22, 8 + b], [32, 5 + b], [42, 8 + b], [48, 16 + b], [47, 28 + b], [42, 36 + b], [32, 38 + b], [22, 36 + b]], P.hair, { sw: 2.5 });
    s += line([[26, 16 + b], [30, 26 + b]], { stroke: "#3a3433", sw: 1.5 }) + line([[38, 14 + b], [36, 24 + b]], { stroke: "#3a3433", sw: 1.5 });
  } else {
    s += shape([[16, 26 + b], [16, 15 + b], [22, 8 + b], [32, 5 + b], [42, 8 + b], [48, 15 + b], [48, 26 + b], [45, 18 + b], [40, 21 + b], [36, 16 + b], [31, 21 + b], [27, 16 + b], [22, 21 + b], [19, 18 + b]], P.hair, { sw: 2.5 });
    s += E(26, 27 + b, 2, 2.8, P.ink, { stroke: "none" }) + E(38, 27 + b, 2, 2.8, P.ink, { stroke: "none" });
    s += fillR(26.3, 25.6 + b, 1, 1, "#fff", 0.9) + fillR(38.3, 25.6 + b, 1, 1, "#fff", 0.9);
    s += line([[23, 22 + b], [29, 21.5 + b]], { sw: 1.8 }) + line([[35, 21.5 + b], [41, 22 + b]], { sw: 1.8 });
    s += arms === "windup" || arms === "release" ? E(32, 33 + b, 2.2, 1.8, P.ink, { stroke: "none" }) : line([[30, 33 + b], [34, 33 + b]], { sw: 1.5 });
    s += E(23, 31 + b, 2.5, 1.5, "#d07a62", { stroke: "none", op: 0.5 }) + E(41, 31 + b, 2.5, 1.5, "#d07a62", { stroke: "none", op: 0.5 });
  }
  return s;
}

// Frame tables. Each entry = options for playerFrame. File: characters/player/<anim>_<dir>_<i>.svg
const F = (bob, stepL, stepR, swing, extra = {}) => ({ bob, stepL, stepR, swing, ...extra });
// side-view cycle: near/far = [thigh, knee] for stride, passing, stride (mirrored), passing
const cycle = (stride, back, support, lift, bobs, swing, extra = {}) => [
  { bob: bobs[0], swing: -swing, legs: { near: stride, far: back }, ...extra },
  { bob: bobs[1], swing: 0, legs: { near: support, far: lift }, ...extra },
  { bob: bobs[0], swing: swing, legs: { near: back, far: stride }, ...extra },
  { bob: bobs[1], swing: 0, legs: { near: lift, far: support }, ...extra },
];
const WALK_SIDE = (extra) => cycle([24, 6], [-20, 20], [2, 6], [26, 60], [0, -1.5], 5, { elbow: 15, ...extra });
const RUN_SIDE = (extra) => cycle([44, 16], [-40, 60], [-6, 24], [70, 135], [-3, 0], 9, { elbow: 85, ...extra });
export const PLAYER_ANIMS = {
  idle: { fps: 3, frames: { all: [F(0, 0, 0, 0), F(1, 0, 0, 1)] } },
  walk: { fps: 9, frames: { all: [F(0, 3, -3, 4), F(-2, 0, 0, 0), F(0, -3, 3, -4), F(-2, 0, 0, 0)],
    side: WALK_SIDE() } },
  run: { fps: 13, frames: { all: [F(-1, 5, -5, 7), F(-4, 0, 0, 0), F(-1, -5, 5, -7), F(-4, 0, 0, 0)],
    side: RUN_SIDE({ lean: 4 }) } },
  carry_idle: { fps: 3, frames: { all: [F(0, 0, 0, 0, { arms: "carry" }), F(1, 0, 0, 0, { arms: "carry" })] } },
  carry_walk: { fps: 9, frames: { all: [F(0, 3, -3, 0, { arms: "carry" }), F(-2, 0, 0, 0, { arms: "carry" }), F(0, -3, 3, 0, { arms: "carry" }), F(-2, 0, 0, 0, { arms: "carry" })],
    side: WALK_SIDE({ arms: "carry" }) } },
  carry_run: { fps: 13, frames: { all: [F(-1, 5, -5, 0, { arms: "carry" }), F(-4, 0, 0, 0, { arms: "carry" }), F(-1, -5, 5, 0, { arms: "carry" }), F(-4, 0, 0, 0, { arms: "carry" })],
    side: RUN_SIDE({ arms: "carry", lean: 3 }) } },
  // pose sets driven frame-by-frame by the AnimationPlayer (fps unused)
  pickup: { fps: 0, frames: { all: [F(0, 0, 0, 0, { arms: "reach", crouch: 5, lean: 3 }), F(0, 0, 0, 0, { arms: "reach", crouch: 10, lean: 5 })] } },
  throw: { fps: 0, frames: { all: [F(0, 0, 0, 0, { arms: "windup", lean: -3 }), F(0, 2, -2, 0, { arms: "release", lean: 4 }), F(1, 0, 0, 0, { arms: "recover", lean: 1 })] } },
};

function character() {
  for (const dir of ["down", "up", "side"]) {
    for (const [anim, def] of Object.entries(PLAYER_ANIMS)) {
      const list = def.frames[dir] ?? def.frames.all;
      list.forEach((opts, i) => {
        seed = 900 + i; // same seed per frame index keeps outlines stable between animations
        save(`characters/player/${anim}_${dir}_${i}.svg`, svg(64, 96, playerFrame(dir, opts)));
      });
    }
  }
  // Portrait for the HUD (head and shoulders, 96x96)
  seed = 11;
  let s = shape([[10, 96], [14, 74], [30, 66], [66, 66], [82, 74], [86, 96]], "#e4dfd0") + line([[26, 70], [24, 96]], { stroke: "#24323f", sw: 5 }) + line([[70, 70], [72, 96]], { stroke: "#24323f", sw: 5 });
  s += `<g transform="translate(-16 -6) scale(2)">` + `<g>` + playerFrame("down").replace(/<ellipse[^>]*opacity="0.3"\/>/, "") + `</g></g>`;
  save("ui/portrait.svg", svg(96, 96, `<clipPath id="c"><rect x="0" y="0" width="96" height="96"/></clipPath><g clip-path="url(#c)">${s}</g>`));
}

// ------------------------------------------------------------- rescue boat
function rescueBoat() {
  seed = 555;
  // 3/4 view wooden rescue boat, 270x136. Front-bottom (waterline) at y = 130.
  let s = shadow(135, 124, 128, 10, 0.25);
  const hullFace = [[8, 54], [58, 82], [212, 82], [262, 46], [218, 112], [64, 116]];
  s += shape(hullFace, P.brownD, { sw: 3.5 });
  s += line([[30, 80], [66, 100], [210, 98], [244, 70]], { stroke: P.mustard, sw: 3 });
  s += hatch(60, 88, 150, 20, 10, { op: 0.25 });
  const rim = [[8, 54], [62, 22], [210, 22], [262, 46], [212, 82], [58, 82]];
  s += shape(rim, P.brownL, { sw: 3.5 });
  const floor = [[30, 54], [70, 32], [204, 32], [238, 48], [204, 72], [68, 72]];
  s += shape(floor, "#5a3b24", { sw: 2.5 });
  for (const y of [40, 48, 56, 64]) s += line([[50, y], [222, y]], { stroke: "#3c2716", sw: 1.2, op: 0.7 });
  s += R(96, 30, 14, 44, P.brown, { sw: 2.5 }) + R(160, 30, 14, 44, P.brown, { sw: 2.5 }); // seat boards
  s += E(226, 52, 9, 6, "#d8662f", { sw: 2.5 }) + E(226, 52, 4, 2.5, "#5a3b24", { sw: 1.5 }); // life ring
  s += line([[8, 54], [-2, 70]], { sw: 2.5, stroke: P.beigeD });
  s += line([[30, 122], [90, 126], [150, 122]], { stroke: P.floodL, sw: 2.5 }) + line([[170, 124], [240, 120]], { stroke: P.floodL, sw: 2.5 });
  save("environments/boat/rescue_boat.svg", svg(270, 136, s));
  // impact dust puff (used by the throw effect)
  seed = 556;
  s = E(16, 16, 13, 9, P.beigeL, { stroke: P.beigeD, sw: 2, op: 0.9 }) + E(10, 13, 5, 4, "#fff", { stroke: "none", op: 0.35 });
  save("environments/boat/dust_puff.svg", svg(32, 32, s));
  // HUD icon for the boat
  seed = 557;
  s = shape([[4, 30], [16, 46], [48, 46], [60, 28], [46, 34], [16, 34]], P.brownL, { sw: 3 }) + line([[12, 40], [52, 40]], { stroke: P.mustard, sw: 2 }) +
    R(26, 14, 14, 16, P.redL, { sw: 2.5 }) + line([[0, 52], [20, 54], [40, 52], [64, 54]], { stroke: P.floodL, sw: 2.5 });
  save("ui/icon_boat.svg", svg(64, 64, s));
}

// ------------------------------------------------------------------- UI kit
function ui() {
  seed = 21;
  // Dark worn panel (9-patch, margins 20)
  let s = shape([[3, 5], [93, 3], [93, 92], [4, 93]], "#23211d", { sw: 4 }) + shape([[9, 10], [87, 9], [87, 87], [9, 87]], "none", { stroke: "#cdbd8f", sw: 1.6, op: 0.55 });
  s += grime(12, 12, 72, 72, 10, "#000", 0.25) + fillR(10, 10, 76, 4, "#fff", 0.04);
  save("ui/panel_dark.svg", svg(96, 96, s));
  // Paper panel (9-patch, margins 32) with tape on the corners
  s = shape([[4, 6], [124, 3], [125, 122], [3, 125]], "#d9c8a0", { sw: 3.5 }) + shape([[10, 12], [118, 10], [118, 116], [10, 118]], "none", { stroke: P.beigeD, sw: 1.5, op: 0.6 });
  s += grime(10, 10, 108, 108, 14, P.beigeD, 0.3);
  s += `<g opacity="0.85">` + shape([[0, 16], [16, 0], [30, 12], [12, 28]], "#c9b27a", { sw: 1.5 }) + shape([[98, 4], [112, -2], [128, 18], [114, 28]], "#c9b27a", { sw: 1.5 }) + `</g>`;
  save("ui/panel_paper.svg", svg(128, 128, s));
  // Plank buttons (9-patch, margins 16)
  const btn = (name, fill, light, dy = 0) => {
    seed = 31;
    let b = shape([[3, 4 + dy], [93, 3 + dy], [93, 44], [3, 45]], fill, { sw: 3 });
    b += fillR(8, 8 + dy, 80, 3, light, 0.5) + shade(6, 36, 84, 6, 0.18) + hatch(10, 14 + dy, 70, 20, 6, { op: 0.12 });
    save(`ui/${name}.svg`, svg(96, 48, b));
  };
  btn("button_normal", P.mustard, P.mustardL);
  btn("button_hover", P.mustardL, "#f3d98a");
  btn("button_pressed", P.mustardD, P.mustard, 3);
  btn("button_disabled", "#77705f", "#958c76");
  // Inventory slot (9-patch, margins 14)
  seed = 41;
  s = shape([[3, 4], [61, 3], [61, 61], [4, 61]], "#2e2b26", { sw: 3 }) + fillR(7, 7, 50, 4, "#000", 0.25) + fillR(7, 53, 50, 3, "#fff", 0.05);
  save("ui/slot.svg", svg(64, 64, s));
  seed = 41;
  s = shape([[3, 4], [61, 3], [61, 61], [4, 61]], "#3a362f", { sw: 3, stroke: P.mustardL }) + fillR(7, 7, 50, 4, "#000", 0.2);
  save("ui/slot_hover.svg", svg(64, 64, s));
  // Key cap for "E" prompt (9-patch, margins 10)
  seed = 51;
  s = shape([[3, 3], [37, 3], [37, 33], [3, 33]], P.cream, { sw: 2.5 }) + fillR(4, 30, 32, 6, P.beigeD) + line([[3, 36], [37, 36]], { sw: 2.5 });
  save("ui/keycap.svg", svg(40, 40, s));
  // Stopwatch icon
  seed = 61;
  s = R(26, 2, 12, 8, P.mustard, { sw: 2.5 }) + E(32, 36, 24, 24, P.cream, { sw: 3.5 }) + E(32, 36, 18, 18, "none", { sw: 1.5, op: 0.6 });
  s += line([[32, 36], [32, 20]], { sw: 3 }) + line([[32, 36], [42, 42]], { sw: 3 }) + E(32, 36, 2.5, 2.5, P.red, { sw: 1.5 }) + line([[50, 14], [56, 8]], { sw: 3 });
  save("ui/icon_clock.svg", svg(64, 64, s));
  // Backpack icon
  seed = 71;
  s = shape([[16, 18], [48, 18], [52, 58], [12, 58]], "#34465a", { sw: 3 }) + R(20, 36, 24, 16, "#24323f", { sw: 2.5 }) + shape([[22, 18], [26, 6], [38, 6], [42, 18]], "none", { sw: 3 });
  s += line([[24, 42], [40, 42]], { stroke: P.mustard, sw: 2 }) + fillR(18, 22, 4, 30, "#fff", 0.12);
  save("ui/icon_bag.svg", svg(64, 64, s));
  // Weight icon
  seed = 81;
  s = shape([[18, 22], [46, 22], [56, 56], [8, 56]], P.charL, { sw: 3 }) + E(32, 16, 7, 7, "none", { sw: 3 }) + fillR(14, 28, 4, 24, "#fff", 0.12);
  save("ui/icon_weight.svg", svg(64, 64, s));
  // Ubon decorative divider (Lotus)
  seed = 91;
  s = line([[4, 16], [86, 16]], { stroke: P.mustard, sw: 2 }) + line([[114, 16], [196, 16]], { stroke: P.mustard, sw: 2 });
  s += shape([[100, 4], [108, 16], [100, 28], [92, 16]], P.mustard, { sw: 2 }) + shape([[90, 14], [96, 22], [86, 26]], P.mustardD, { sw: 1.5 }) + shape([[110, 14], [104, 22], [114, 26]], P.mustardD, { sw: 1.5 });
  save("ui/divider.svg", svg(200, 32, s));
}

// Touch controls (mobile) + platform picker icons
function touchUi() {
  seed = 77;
  const ring = (c, r, fill, op, stroke, sw) => E(c, c, r, r, fill, { stroke, sw, op });
  // action button 132x132: idle = dark glass with a mustard rim, pressed = filled mustard
  save("ui/touch_button.svg", svg(132, 132, ring(66, 60, "#23211d", 0.62, P.ink, 4) + E(66, 66, 54, 54, "none", { stroke: P.mustardL, sw: 3, op: 0.9 }) + fillR(30, 26, 72, 6, "#fff", 0.05)));
  save("ui/touch_button_pressed.svg", svg(132, 132, ring(66, 66, P.mustard, 0.95, P.ink, 4) + E(66, 66, 54, 54, "none", { stroke: P.mustardL, sw: 3 }) + shade(16, 82, 100, 26, 0.15)));
  // virtual stick: base 220x220 with direction ticks, knob 96x96
  let b = ring(110, 100, "#23211d", 0.45, P.ink, 4) + E(110, 110, 92, 92, "none", { stroke: P.cream, sw: 2, op: 0.35 });
  for (const [dx, dy] of [[0, -1], [0, 1], [-1, 0], [1, 0]]) {
    const cx = 110 + dx * 74, cy = 110 + dy * 74, px = -dy, py = dx;
    b += shape([[cx + dx * 10, cy + dy * 10], [cx + px * 9, cy + py * 9], [cx - px * 9, cy - py * 9]], P.cream, { sw: 1.5, op: 0.6 });
  }
  save("ui/touch_stick_base.svg", svg(220, 220, b));
  save("ui/touch_stick_knob.svg", svg(96, 96, ring(48, 42, P.mustard, 0.95, P.ink, 3.5) + E(48, 48, 30, 30, "none", { stroke: P.mustardL, sw: 3 }) + E(40, 38, 10, 7, "#fff", { stroke: "none", op: 0.25 })));
  // pause 76x76
  const pause = (fill, op) => ring(38, 33, fill, op, P.ink, 3.5) + R(26, 23, 8, 30, P.cream, { sw: 2 }) + R(42, 23, 8, 30, P.cream, { sw: 2 });
  save("ui/touch_pause.svg", svg(76, 76, pause("#23211d", 0.7)));
  save("ui/touch_pause_pressed.svg", svg(76, 76, pause(P.mustardD, 0.95)));
  // picker icons 160x120
  seed = 78;
  let pc = R(22, 8, 116, 74, P.char, { sw: 3.5 }) + R(30, 15, 100, 58, "#4c6575", { sw: 2 }) + fillR(36, 20, 40, 5, "#fff", 0.15);
  pc += R(70, 82, 20, 12, P.charL, { sw: 2.5 }) + R(50, 92, 60, 7, P.charL, { sw: 2.5 });
  pc += shape([[14, 104], [146, 104], [154, 116], [6, 116]], P.beigeL, { sw: 3 });
  for (let x = 20; x < 140; x += 12) pc += line([[x, 109], [x + 6, 109]], { sw: 2, stroke: P.beigeD });
  save("ui/icon_pc.svg", svg(160, 120, pc));
  let ph = R(10, 24, 140, 76, P.char, { sw: 3.5 }) + R(26, 32, 108, 60, "#4c6575", { sw: 2 }) + E(18, 62, 2.5, 2.5, P.charL, { sw: 1 });
  ph += E(46, 74, 12, 12, "#23211d", { stroke: P.cream, sw: 2, op: 0.8 }) + E(46, 74, 5, 5, P.mustard, { sw: 1.5 });
  ph += E(110, 68, 8, 8, P.mustard, { sw: 1.5 }) + E(124, 80, 8, 8, P.mustard, { sw: 1.5 });
  ph += shape([[2, 110], [22, 96], [40, 104], [30, 118], [4, 118]], P.skin, { sw: 2.5 }) + shape([[158, 110], [138, 96], [120, 104], [130, 118], [156, 118]], P.skin, { sw: 2.5 });
  save("ui/icon_phone.svg", svg(160, 120, ph));
  // rotate-your-phone hint 200x160
  let rot = R(20, 40, 70, 110, P.char, { sw: 3.5, op: 0.5 }) + R(80, 70, 110, 70, P.char, { sw: 3.5 }) + R(90, 78, 90, 54, "#4c6575", { sw: 2 });
  rot += line([[60, 30], [100, 14], [140, 30]], { sw: 4, stroke: P.mustard }) + shape([[140, 30], [128, 18], [146, 18]], P.mustard, { sw: 2 });
  save("ui/icon_rotate.svg", svg(200, 160, rot));
}

// Arrow and triangle icons used instead of the ← ↑ ↓ → ▸ ◀ ▶ glyphs (the bundled fonts have none)
function glyphIcons() {
  seed = 91;
  const INK = "#2b2926";
  const rot = (pts, deg, c) => pts.map(([x, y]) => {
    const r = (deg * Math.PI) / 180;
    return [c + (x - c) * Math.cos(r) - (y - c) * Math.sin(r), c + (x - c) * Math.sin(r) + (y - c) * Math.cos(r)];
  });
  const arrow = [[20, 4], [36, 20], [26, 20], [26, 36], [14, 36], [14, 20], [4, 20]]; // pointing up in a 40x40 box
  for (const [name, deg] of [["up", 0], ["right", 90], ["down", 180], ["left", 270]])
    save("ui/icon_arrow_" + name + ".svg", svg(40, 40, shape(rot(arrow, deg, 20), INK, { stroke: INK, sw: 2.5, w: 0.3 })));
  const tri = [[5, 3], [17, 10], [5, 17]];
  save("ui/icon_tri_right.svg", svg(20, 20, shape(tri, INK, { stroke: INK, sw: 2, w: 0.2 })));
  save("ui/icon_tri_left.svg", svg(20, 20, shape(tri.map(([x, y]) => [20 - x, y]), INK, { stroke: INK, sw: 2, w: 0.2 })));
  save("ui/icon_skip.svg", svg(30, 20, shape(tri, INK, { stroke: INK, sw: 2, w: 0.2 }) + shape(tri.map(([x, y]) => [x + 11, y]), INK, { stroke: INK, sw: 2, w: 0.2 })));
}

// ------------------------------------------------------------- backgrounds
function templeSilhouette(x, base, sc, color) {
  // Square, tiered white-stupa silhouette inspired by Ubon temples (not a copy of any game asset)
  const t = (pts) => shape(pts.map(([px, py]) => [x + px * sc, base - py * sc]), color, { sw: 2.5 });
  return t([[-60, 0], [60, 0], [52, 30], [-52, 30]]) + t([[-42, 30], [42, 30], [34, 70], [-34, 70]]) + t([[-26, 70], [26, 70], [20, 110], [-20, 110]]) +
    t([[-14, 110], [14, 110], [4, 190], [-4, 190]]) + t([[-120, 0], [-70, 0], [-78, 40], [-95, 58], [-112, 40]]) + t([[70, 0], [120, 0], [112, 40], [95, 58], [78, 40]]);
}
function thaiRoofHouse(x, base, w, h, color, roof) {
  return shape([[x, base], [x + w, base], [x + w, base - h], [x, base - h]], color, { sw: 2.5 }) +
    shape([[x - 14, base - h], [x + w + 14, base - h], [x + w / 2, base - h - w * 0.55]], roof, { sw: 2.5 }) +
    line([[x + w / 2, base - h - w * 0.55], [x + w / 2 + 6, base - h - w * 0.55 - 12]], { sw: 2.5 });
}
// Main menu: the flooded riverside market hall in Ubon (long red-roofed building on stilts,
// raft houses, brown floodwater, overcast sky) — redrawn in the game's hand-drawn style.
function menuBackground(W, H) {
  seed = 4242;
  const defs = '<linearGradient id="msky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7d8ea0"/><stop offset="0.55" stop-color="#aab6bf"/><stop offset="1" stop-color="#cdd3d4"/></linearGradient>' +
    '<linearGradient id="mwater" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#9a8a72"/><stop offset="0.35" stop-color="#7d6c55"/><stop offset="1" stop-color="#4f4232"/></linearGradient>';
  const ROOF = "#c9625a", ROOF_D = "#a1463f", ROOF_L = "#dc8178", WALL = "#ece6da", WALL_D = "#bdb5a8", WIN = "#4a5560", POST = "#e6e0d3";
  // perspective of the long hall: near end at x = -40, far end at x = 940
  const X0 = -40, X1 = 940;
  const k = (x) => Math.min(1, Math.max(0, (x - X0) / (X1 - X0)));
  const lerp = (a, b, x) => a + (b - a) * k(x);
  const top = (x) => lerp(150, 352, x), eave = (x) => lerp(262, 370, x), floorB = (x) => lerp(330, 392, x), water = (x) => lerp(500, 410, x);

  let o = fillR(0, 0, W, 430, "url(#msky)");
  // low rain clouds
  for (let i = 0; i < 9; i++) o += E(rnd() * W, 40 + rnd() * 220, 140 + rnd() * 160, 18 + rnd() * 16, i % 2 ? "#8995a3" : "#9aa5b1", { stroke: "none", op: 0.6 });
  // far shore: tree line + small white pavilion on the right
  for (let x = 880; x < W + 40; x += 34 + rnd() * 20) o += E(x, 398 - rnd() * 14, 30 + rnd() * 16, 18 + rnd() * 10, rnd() > 0.5 ? "#5b6b48" : "#4c5c3d", { sw: 2 });
  o += fillR(860, 400, W - 860, 14, "#59684a");
  o += R(1140, 372, 56, 26, "#e9e5dc", { sw: 2 }) + shape([[1132, 374], [1204, 374], [1186, 358], [1150, 358]], "#d5d0c6", { sw: 2 }) + R(1144, 398, 4, 12, POST, { sw: 1.5 }) + R(1188, 398, 4, 12, POST, { sw: 1.5 });
  o += R(1040, 392, 30, 14, "#c9a989", { sw: 1.8 }) + shape([[1036, 393], [1074, 393], [1066, 384], [1044, 384]], ROOF_D, { sw: 1.8 });

  // water (drawn before the hall so stilts stand in it)
  o += fillR(0, 404, W, H - 404, "url(#mwater)");

  // white block behind the roofs (the second building)
  o += R(460, 244, 230, 80, WALL, { sw: 2.5 }) + R(460, 244, 230, 10, WALL_D, { sw: 2 });
  for (let x = 470; x < 680; x += 22) o += R(x, 262, 13, 10, WIN, { sw: 1.5 });

  // under-floor shadow + stilts standing in the water
  o += shape([[X0, floorB(X0)], [X1, floorB(X1)], [X1, water(X1)], [X0, water(X0)]], "#3a3530", { sw: 2.5 });
  for (let x = X0 + 40; x < X1; x += 18 + 60 * (1 - k(x))) {
    const w = 4 + 8 * (1 - k(x));
    o += R(x, floorB(x), w, water(x) - floorB(x) + 4, POST, { sw: 2 });
  }
  // staircases down into the water
  for (const sx of [120, 300]) {
    const b = floorB(sx), wl = water(sx);
    o += shape([[sx, b], [sx + 14, b], [sx + 70, wl], [sx + 54, wl]], POST, { sw: 2 });
    for (let t = 0.15; t < 1; t += 0.17) o += line([[sx + 56 * t, b + (wl - b) * t], [sx + 14 + 56 * t, b + (wl - b) * t]], { sw: 1.5 });
  }

  // upper floor: white wall with a long window strip
  o += shape([[X0, eave(X0)], [X1, eave(X1)], [X1, floorB(X1)], [X0, floorB(X0)]], WALL, { sw: 3 });
  o += shape([[X0, floorB(X0) - 10], [X1, floorB(X1) - 4], [X1, floorB(X1)], [X0, floorB(X0)]], WALL_D, { sw: 2 });
  for (let x = X0 + 30; x < X1 - 10; x += 14 + 30 * (1 - k(x))) {
    const h = (floorB(x) - eave(x)) * 0.42, y = eave(x) + (floorB(x) - eave(x)) * 0.22, w = 6 + 18 * (1 - k(x));
    o += R(x, y, w, h, WIN, { sw: 1.5 });
  }

  // main hip roof (near half of the hall)
  const rx = 520;
  o += shape([[X0, eave(X0) + 8], [rx, eave(rx) + 6], [rx - 40, top(rx - 40)], [X0 + 30, top(X0 + 30)]], ROOF, { sw: 3.5 });
  o += shape([[X0, eave(X0) + 8], [rx, eave(rx) + 6], [rx, eave(rx) - 4], [X0, eave(X0) - 6]], ROOF_D, { sw: 2.5 });
  for (let i = 1; i < 6; i++) { const f = i / 6; o += line([[X0 + 20, top(X0) + (eave(X0) - top(X0)) * f], [rx - 30, top(rx) + (eave(rx) - top(rx)) * f]], { stroke: ROOF_D, sw: 1.5, op: 0.5 }); }
  o += line([[X0 + 30, top(X0 + 30)], [rx - 40, top(rx - 40)]], { sw: 3 });
  // projecting front gable with the hall's name board
  const gx = 170, gw = 210, gy = eave(gx + gw / 2) + 26;
  o += shape([[gx, gy], [gx + gw, gy], [gx + gw / 2, gy - 120]], ROOF_L, { sw: 3.5 });
  o += shape([[gx - 8, gy + 4], [gx + gw / 2, gy - 126], [gx + gw + 8, gy + 4], [gx + gw - 4, gy + 6], [gx + gw / 2, gy - 112], [gx + 4, gy + 6]], ROOF_D, { sw: 2.5 });
  o += R(gx + 34, gy - 44, gw - 68, 18, "#f2eee4", { sw: 2 });
  for (let x = gx + 42; x < gx + gw - 44; x += 9) o += fillR(x, gy - 39, 6, 8, "#7a3b33", 0.85);
  o += shape([[gx + 96, gy - 92], [gx + gw / 2, gy - 104], [gx + gw - 96, gy - 92], [gx + gw / 2, gy - 84]], "#e8c66a", { sw: 1.5 });

  // smaller pavilion roofs receding along the river
  for (let x = rx - 10; x < X1 - 10;) {
    const w = 40 + 100 * (1 - k(x)), e = eave(x + w / 2) + 4, h = (eave(x) - top(x)) * 0.5;
    o += shape([[x - 6, e], [x + w + 6, e], [x + w * 0.8, e - h], [x + w * 0.2, e - h]], ROOF, { sw: 2.5 });
    o += shape([[x + w * 0.24, e - h], [x + w * 0.5, e - h * 1.5], [x + w * 0.76, e - h]], ROOF_L, { sw: 2.2 });
    o += shape([[x + w * 0.24, e - h], [x + w * 0.76, e - h], [x + w * 0.7, e - h * 0.88], [x + w * 0.3, e - h * 0.88]], ROOF_D, { sw: 1.8 });
    o += line([[x - 4, e], [x + w + 4, e]], { stroke: ROOF_D, sw: 3 });
    x += w * 0.92;
  }

  // raft house (floating shop) moored in front of the hall
  const fx = 470, fy = 470;
  o += R(fx - 6, fy + 18, 196, 12, "#5a4634", { sw: 2.5 });
  o += R(fx, fy - 24, 82, 44, "#4f87b8", { sw: 2.5 }) + R(fx + 82, fy - 24, 102, 44, "#c4b49a", { sw: 2.5 });
  o += R(fx + 12, fy - 14, 22, 18, "#2d3a46", { sw: 1.8 }) + R(fx + 104, fy - 14, 26, 24, "#6a5440", { sw: 1.8 }) + R(fx + 142, fy - 14, 28, 14, "#2d3a46", { sw: 1.8 });
  o += shape([[fx - 16, fy - 22], [fx + 200, fy - 22], [fx + 176, fy - 52], [fx + 8, fy - 52]], "#9aa39a", { sw: 3 });
  for (let x = fx; x < fx + 190; x += 10) o += line([[x, fy - 50], [x - 4, fy - 24]], { stroke: "#7d877e", sw: 1.2 });
  o += R(fx + 190, fy - 8, 64, 26, "#c9b79c", { sw: 2.2 }) + shape([[fx + 184, fy - 8], [fx + 260, fy - 8], [fx + 248, fy - 26], [fx + 196, fy - 26]], "#a9aea6", { sw: 2.2 });
  o += line([[fx - 10, fy + 32], [fx + 260, fy + 32]], { stroke: "#c9b79c", sw: 2, op: 0.6 });
  // a couple of small boats by the far pavilions
  o += shape([[760, 418], [772, 426], [826, 426], [836, 416], [826, 420], [772, 420]], "#5a4030", { sw: 2 });
  o += shape([[868, 414], [876, 420], [912, 420], [920, 412], [912, 416], [876, 416]], "#6a7a8a", { sw: 1.8 });

  // reflections of the roof and the white wall in the muddy water
  o += shape([[X0, water(X0) + 4], [rx, water(rx) + 4], [rx, water(rx) + 60], [X0, water(X0) + 90]], ROOF, { stroke: "none", op: 0.16 });
  o += shape([[rx, water(rx) + 4], [X1, water(X1) + 2], [X1, water(X1) + 20], [rx, water(rx) + 40]], ROOF, { stroke: "none", op: 0.12 });
  // flooded promenade: railing and lamp posts poking out near the camera
  o += line([[-10, 548], [420, 520]], { sw: 3.5, stroke: "#2c2722" });
  for (let x = 0; x < 420; x += 34) o += R(x, 548 - x * 0.065 - 2, 4, 20, "#2c2722", { sw: 1.5 });
  for (const lx of [92, 200]) {
    const ly = 548 - lx * 0.065;
    o += R(lx, ly - 70, 5, 84, "#1f1b18", { sw: 1.5 }) + E(lx + 2.5, ly - 74, 6, 7, "#d9d2c0", { sw: 2 });
  }
  // ripples
  for (let i = 0; i < 90; i++) {
    const y = 420 + rnd() * 300, x = rnd() * W, l = 18 + rnd() * 90 * (y / 720);
    o += line([[x, y], [x + l, y + jit(1)]], { stroke: i % 3 ? "#b8a68a" : "#3f3427", sw: 1.2 + rnd() * 1.6, op: 0.25 + rnd() * 0.35 });
  }
  // drizzle
  for (let i = 0; i < 140; i++) { const x = rnd() * W, y = rnd() * H; o += line([[x, y], [x - 4, y + 16]], { stroke: "#eef2f3", sw: 1, op: 0.16 }); }
  return svg(W, H, o, defs);
}

function backgrounds() {
  seed = 123;
  const W = 1280, H = 720;
  save("ui/menu_bg.svg", menuBackground(W, H));
  let s;

  // Summary background: night, rooftops above the water line, the family's boat waiting
  seed = 321;
  const defs2 = `<linearGradient id="n" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#151a26"/><stop offset="0.6" stop-color="#2c3a4a"/><stop offset="1" stop-color="#3d5a5c"/></linearGradient>
<linearGradient id="w2" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2f5554"/><stop offset="1" stop-color="#132322"/></linearGradient>`;
  s = fillR(0, 0, W, 430, "url(#n)") + E(1120, 110, 38, 38, "#e8e0c4", { stroke: "none", op: 0.85 });
  for (let i = 0; i < 6; i++) s += E(rnd() * W, 60 + rnd() * 180, 140, 16, "#262d3d", { stroke: "none", op: 0.7 });
  s += templeSilhouette(1040, 430, 1.1, "#1a1e2a");
  s += thaiRoofHouse(80, 430, 160, 40, "#171a22", "#11141a") + thaiRoofHouse(380, 430, 130, 30, "#1b1f28", "#13161d") + thaiRoofHouse(700, 430, 150, 46, "#171a22", "#11141a");
  s += fillR(0, 430, W, 290, "url(#w2)");
  for (let i = 0; i < 60; i++) { const y = 440 + rnd() * 270, x = rnd() * W; s += line([[x, y], [x + 30 + rnd() * 60, y]], { stroke: "#8fb1b4", sw: 1.5, op: 0.15 + rnd() * 0.3 }); }
  s += shape([[860, 600], [920, 632], [1180, 632], [1240, 590], [1180, 612], [920, 612]], "#2a1d14", { sw: 3 }) + R(1000, 586, 40, 28, "#e1a050", { sw: 2.5, op: 0.9 });
  for (let i = 0; i < 200; i++) { const x = rnd() * W, y = rnd() * H; s += line([[x, y], [x - 4, y + 16]], { stroke: "#cfdde0", sw: 1, op: 0.15 }); }
  save("ui/summary_bg.svg", svg(W, H, s, defs2));
}

// ============================================================ PART 2 ART
// THE FIRST NIGHT — boat on the flood at night. Night colour comes from a
// CanvasModulate in the scene, so these are drawn in normal (dusk) colours.

// Seated survivor, 96x128. Seat (hips) at y = 118, centre x = 48.
// pose: idle0 | idle1 (breath) | look (glances to the side)
const SURVIVORS = {
  player: { shirt: "#e4dfd0", shirtD: "#b7b0a0", pants: "#2e3440", hair: "spiky", strap: true },
  mother: { shirt: "#6f7a4a", shirtD: "#535c34", pants: "#7a3b2e", hair: "bun", dots: true },
  sister: { shirt: "#c48a86", shirtD: "#9c6762", pants: "#3a3f52", hair: "pigtails", scale: 0.8 },
  grandpa: { shirt: "#8a6a4a", shirtD: "#6a4f36", pants: "#4d4b48", hair: "old", mustache: true, thin: true },
};

function seated(who, pose) {
  const c = SURVIVORS[who];
  const b = pose === "idle1" ? 1.5 : 0;
  const hx = pose === "look" ? 2.5 : 0; // head turn
  const px = pose === "look" ? 1.6 : 0; // pupils
  const w = c.thin ? 3 : 0;
  let s = shadow(48, 120, 30, 5, 0.25);
  // knees + shins (mostly hidden behind the boat's front rim)
  s += R(32, 104, 10, 22, c.pants, { sw: 2.5 }) + R(54, 104, 10, 22, c.pants, { sw: 2.5 });
  s += E(38, 102, 11, 9, c.pants, { sw: 2.5 }) + E(58, 102, 11, 9, c.pants, { sw: 2.5 });
  // torso
  s += shape([[30 + w, 68 + b], [66 - w, 68 + b], [71 - w, 112], [25 + w, 112]], c.shirt);
  s += fillR(28 + w, 96, 40 - 2 * w, 15, "#000", 0.12);
  if (c.dots) for (let i = 0; i < 9; i++) s += E(34 + (i % 3) * 12 + (i > 2 ? 4 : 0), 76 + Math.floor(i / 3) * 10 + b, 1.6, 1.6, c.shirtD, { stroke: "none" });
  if (c.strap) s += line([[36, 69 + b], [34, 100]], { stroke: "#24323f", sw: 4 }) + line([[60, 69 + b], [62, 100]], { stroke: "#24323f", sw: 4 });
  s += shape([[42, 68 + b], [48, 75 + b], [54, 68 + b]], c.shirtD, { sw: 2 });
  // arms hugging the knees
  s += shape([[30 + w, 70 + b], [24 + w, 92], [30, 98], [36 + w, 78 + b]], c.shirt, { sw: 2.5 });
  s += shape([[66 - w, 70 + b], [72 - w, 92], [66, 98], [60 - w, 78 + b]], c.shirt, { sw: 2.5 });
  s += R(27, 92, 42, 9, P.skin, { sw: 2.5 }) + E(46, 96, 5, 4, P.skin, { sw: 2 }) + E(52, 95, 4.5, 4, P.skin, { sw: 2 });
  // neck + head
  s += R(43 + hx * 0.4, 58 + b, 10, 10, P.skinD, { sw: 2 });
  const H = (x, y) => [x + hx, y + b];
  s += E(48 + hx, 44 + b, 16, 17, P.skin) + E(32 + hx, 46 + b, 2.8, 4, P.skin, { sw: 2 }) + E(64 + hx, 46 + b, 2.8, 4, P.skin, { sw: 2 });
  // hair
  if (c.hair === "spiky") {
    s += shape([H(31, 46), H(31, 33), H(38, 26), H(48, 23), H(58, 26), H(65, 33), H(65, 46), H(62, 37), H(57, 40), H(53, 35), H(48, 40), H(43, 35), H(38, 40), H(34, 37)], P.hair, { sw: 2.5 });
  } else if (c.hair === "bun") {
    s += E(48 + hx, 24 + b, 8, 7, P.hair, { sw: 2.5 });
    s += shape([H(31, 50), H(31, 36), H(38, 28), H(48, 26), H(58, 28), H(65, 36), H(65, 50), H(61, 38), H(48, 33), H(35, 38)], P.hair, { sw: 2.5 });
    s += line([H(36, 40), H(33, 56)], { stroke: P.hair, sw: 2 }); // loose wet strand
  } else if (c.hair === "pigtails") {
    s += E(29 + hx, 52 + b, 5, 9, P.hair, { sw: 2.5 }) + E(67 + hx, 52 + b, 5, 9, P.hair, { sw: 2.5 });
    s += shape([H(31, 46), H(31, 34), H(38, 27), H(48, 25), H(58, 27), H(65, 34), H(65, 46), H(60, 36), H(48, 34), H(36, 36)], P.hair, { sw: 2.5 });
    s += E(31 + hx, 44 + b, 2.5, 2.5, P.redL, { sw: 1.2 }) + E(65 + hx, 44 + b, 2.5, 2.5, P.redL, { sw: 1.2 });
  } else {
    s += shape([H(31, 50), H(32, 38), H(37, 33), H(37, 46)], "#d9d6cc", { sw: 2 }) + shape([H(65, 50), H(64, 38), H(59, 33), H(59, 46)], "#d9d6cc", { sw: 2 });
    s += line([H(40, 32), H(46, 30)], { stroke: P.skinD, sw: 1.2 }) + line([H(42, 36), H(54, 35)], { stroke: P.skinD, sw: 1 });
  }
  // tired, worried face: inner brow ends raised, heavy lids, small frown
  const eyeY = 47;
  for (const ex of [42, 55]) {
    s += E(ex + hx + px, eyeY + b, 1.7, 2.1, P.ink, { stroke: "none" });
    s += line([H(ex - 3.5, eyeY - 1.6), H(ex + 3.5, eyeY - 2.2)], { sw: 1.6 });
    s += line([H(ex - 2.5, eyeY + 3.6), H(ex + 2.5, eyeY + 3.8)], { sw: 0.9, op: 0.45 }); // bags under eyes
  }
  s += line([H(37, 42), H(45, 39)], { sw: 2 }) + line([H(51, 39), H(59, 42)], { sw: 2 });
  if (c.mustache) s += shape([H(42, 54.5), H(48, 53), H(54, 54.5), H(52, 57), H(48, 56), H(44, 57)], "#e2dfd6", { sw: 1.5 });
  s += pose === "look" ? line([H(45, 58), H(51, 58)], { sw: 1.6 }) : `<path d="M${44 + hx} ${59 + b} Q${48 + hx} ${56.2 + b} ${52 + hx} ${59 + b}" fill="none" stroke="${P.ink}" stroke-width="1.6" stroke-linecap="round"/>`;
  s += E(37 + hx, 53 + b, 2.5, 1.4, "#c07a68", { stroke: "none", op: 0.35 }) + E(59 + hx, 53 + b, 2.5, 1.4, "#c07a68", { stroke: "none", op: 0.35 });
  // rain-wet sheen
  s += line([H(36, 30), H(41, 27)], { stroke: "#fff", sw: 1.4, op: 0.35 });
  if (c.scale) s = `<g transform="translate(${48 * (1 - c.scale)} ${120 * (1 - c.scale)}) scale(${c.scale})">${s}</g>`;
  return s;
}

function part2Art() {
  // ---- survivors
  for (const who of Object.keys(SURVIVORS)) {
    for (const pose of ["idle0", "idle1", "look"]) {
      seed = 1200 + pose.length;
      save(`characters/survivors/${who}_${pose}.svg`, svg(96, 128, seated(who, pose)));
    }
  }

  // ---- boat (660x330): back half (floor, rim, bench, lamp pole) and front half (hull + front rim)
  seed = 1300;
  let s = shape([[30, 178], [130, 112], [540, 112], [635, 160], [610, 170], [530, 130], [140, 130], [70, 180]], P.brownL, { sw: 3.5 });
  s += shape([[70, 180], [140, 130], [530, 130], [610, 170], [530, 222], [140, 228]], "#5a3b24", { sw: 3 });
  for (const y of [145, 160, 175, 190, 205]) s += line([[95, y], [590, y - 2]], { stroke: "#3c2716", sw: 1.4, op: 0.7 });
  s += hatch(120, 140, 420, 70, 26, { color: "#2a1a0e", op: 0.3 });
  s += R(240, 128, 26, 96, P.brown, { sw: 3 }) + fillR(242, 130, 4, 92, "#fff", 0.12);
  s += R(90, 18, 8, 168, P.brownD, { sw: 2.5 }) + R(90, 18, 38, 7, P.brownD, { sw: 2.5 }); // lamp pole + arm
  s += E(560, 150, 22, 9, "#d8662f", { sw: 3 }) + E(560, 150, 10, 4, "#5a3b24", { sw: 2 }); // life ring
  save("environments/boat/night_boat_back.svg", svg(660, 330, s));
  seed = 1301;
  s = shape([[30, 178], [70, 180], [140, 228], [530, 222], [610, 170], [635, 160], [552, 286], [122, 292]], P.brownD, { sw: 3.5 });
  s += line([[60, 228], [140, 262], [540, 256], [600, 214]], { stroke: P.mustard, sw: 4 });
  s += hatch(140, 236, 380, 40, 22, { op: 0.25 });
  for (const x of [200, 300, 400, 500]) s += line([[x, 228], [x - 4, 288]], { stroke: "#2c1a10", sw: 1.4, op: 0.6 });
  s += line([[30, 178], [140, 230], [530, 224], [635, 160]], { stroke: P.brownL, sw: 11 });
  s += line([[30, 178], [140, 230], [530, 224], [635, 160]], { stroke: P.ink, sw: 2, op: 0.8 });
  s += line([[36, 175], [140, 224], [530, 218], [630, 156]], { stroke: P.cream, sw: 1.5, op: 0.35 });
  save("environments/boat/night_boat_front.svg", svg(660, 330, s));
  seed = 1302;
  s = line([[16, 0], [16, 10]], { sw: 2 }) + R(6, 10, 20, 6, P.charL, { sw: 2 }) + shape([[7, 16], [25, 16], [27, 40], [5, 40]], "#f2c66a", { sw: 2.5 });
  s += line([[16, 18], [16, 38]], { stroke: P.charL, sw: 1.5 }) + E(16, 30, 4, 6, "#fff3c4", { stroke: "none" }) + R(4, 40, 24, 6, P.charL, { sw: 2 });
  save("environments/boat/oil_lamp.svg", svg(32, 48, s));
  // flashlight beam (used as a light texture: white -> transparent cone)
  s = `<path d="M0 64 L256 0 L256 128 Z" fill="url(#cone)"/>`;
  save("environments/boat/beam_cone.svg", svg(256, 128, s, `<linearGradient id="cone" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#fff" stop-opacity="1"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>`));

  // ---- background: sky + far community silhouette
  seed = 1400;
  s = fillR(0, 0, 1280, 440, "url(#sky)");
  s += E(1010, 70, 70, 50, "#9aa7b0", { stroke: "none", op: 0.12 });
  for (let i = 0; i < 16; i++) s += E(rnd() * 1300, 30 + rnd() * 260, 110 + rnd() * 160, 18 + rnd() * 22, i % 3 ? "#1b2232" : "#2a3446", { stroke: "none", op: 0.65 });
  save("backgrounds/night_sky.svg", svg(1280, 440, s, `<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#0f131d"/><stop offset="0.6" stop-color="#1f2a3a"/><stop offset="1" stop-color="#344456"/></linearGradient>`));
  seed = 1401;
  const sil = "#151c25", silL = "#1d2631";
  s = templeSilhouette(980, 220, 0.9, silL);
  for (const [x, w, h] of [[20, 120, 60], [210, 90, 46], [520, 140, 70], [760, 100, 50], [1120, 130, 64]]) s += thaiRoofHouse(x, 220, w, h, sil, "#10161d");
  for (const [x, r] of [[160, 40], [420, 55], [690, 38], [880, 46], [1250, 50]]) s += E(x, 220 - r * 0.7, r, r * 0.8, "#131d1a", { stroke: "#0c1210", sw: 2 });
  for (const x of [340, 650, 1060]) s += R(x, 120, 6, 100, sil, { sw: 2 }) + R(x - 14, 128, 34, 4, sil, { sw: 1.5 });
  s += line([[343, 124], [500, 140], [653, 124]], { stroke: "#0c1015", sw: 1.5 }) + line([[653, 124], [850, 142], [1063, 124]], { stroke: "#0c1015", sw: 1.5 });
  s += fillR(0, 214, 1280, 6, "#0c1015");
  save("backgrounds/far_community.svg", svg(1280, 220, s));

  // ---- mid-ground props (bottom of each image = waterline)
  seed = 1500;
  // stilt house, half under water, one lit window (the lit pane is a separate light in the scene)
  s = R(30, 70, 220, 110, "#4a3626") + hatch(36, 76, 200, 96, 18, { op: 0.3 });
  for (let x = 40; x < 250; x += 22) s += line([[x, 72], [x, 178]], { stroke: "#2f2119", sw: 1.4, op: 0.8 });
  s += shape([[10, 72], [270, 72], [140, 4]], "#3a2d2a") + line([[140, 4], [148, -8]], { sw: 2.5 });
  s += R(60, 96, 46, 40, "#1c1612", { sw: 3 }) + R(170, 96, 46, 40, "#e8b257", { sw: 3 }) + line([[193, 96], [193, 136]], { sw: 2.5 }) + line([[170, 116], [216, 116]], { sw: 2.5 });
  s += R(26, 176, 228, 10, "#2f2119", { sw: 2.5 });
  for (const x of [40, 110, 180, 240]) s += R(x, 186, 10, 40, "#2f2119", { sw: 2 });
  s += fillR(0, 214, 280, 16, "#2a4a4c", 0.8) + line([[0, 214], [280, 214]], { stroke: "#6b9a96", sw: 2, op: 0.7 });
  save("backgrounds/house_stilt_night.svg", svg(280, 230, s));
  // one-storey house: only the roof is left above the water
  seed = 1501;
  s = shape([[10, 96], [250, 96], [130, 14]], "#40322c") + line([[130, 14], [130, 96]], { stroke: "#2a201c", sw: 1.5, op: 0.6 });
  for (let i = 0; i < 6; i++) s += line([[30 + i * 34, 96], [130, 18]], { stroke: "#2a201c", sw: 1.2, op: 0.5 });
  s += R(90, 74, 28, 22, "#1a1411", { sw: 2 }) + E(60, 92, 10, 4, "#d8d0bd", { sw: 1.5 }); // vent + stuck bag
  s += fillR(0, 96, 260, 14, "#2a4a4c", 0.85) + line([[0, 96], [260, 96]], { stroke: "#6b9a96", sw: 2, op: 0.7 });
  save("backgrounds/roof_submerged.svg", svg(260, 110, s));
  // shopfront: faded sign board (Thai text is a Label in the scene) + awning
  seed = 1502;
  s = R(30, 70, 8, 90, "#2f2a26", { sw: 2 }) + R(200, 70, 8, 90, "#2f2a26", { sw: 2 });
  s += shape([[6, 22], [230, 16], [234, 70], [10, 76]], "#3c5a7a", { sw: 3.5 }) + shape([[14, 28], [222, 23], [226, 64], [18, 69]], "none", { stroke: "#cfd8dc", sw: 2, op: 0.8 });
  s += grime(14, 26, 210, 40, 14, "#1d2c3a", 0.5);
  for (let i = 0; i < 7; i++) s += shape([[10 + i * 32, 78], [42 + i * 32, 78], [38 + i * 32, 98], [14 + i * 32, 98]], i % 2 ? "#8a3a2e" : "#c9c0aa", { sw: 2 });
  s += fillR(0, 140, 240, 20, "#2a4a4c", 0.85) + line([[0, 140], [240, 140]], { stroke: "#6b9a96", sw: 2, op: 0.7 });
  save("backgrounds/shop_sign.svg", svg(240, 160, s));
  // tree standing in water
  seed = 1503;
  s = shape([[96, 240], [112, 240], [110, 120], [98, 120]], "#3a2c22") + line([[104, 150], [80, 110]], { stroke: "#3a2c22", sw: 6 });
  for (const [x, y, r] of [[70, 90, 46], [130, 80, 52], [100, 46, 50], [60, 54, 34], [150, 120, 34]]) s += E(x, y, r, r * 0.8, "#24342a", { sw: 2.5 });
  s += hatch(40, 30, 140, 100, 20, { color: "#16201a", op: 0.5 });
  s += E(104, 236, 26, 5, "#2a4a4c", { sw: 1.5, stroke: "#6b9a96" });
  save("backgrounds/tree_flooded.svg", svg(200, 244, s));
  // floating bits
  seed = 1504;
  save("environments/outside/leaf_cluster.svg", svg(48, 24, E(14, 12, 10, 5, "#4b5a2e", { sw: 2 }) + E(30, 13, 9, 4, "#6d7438", { sw: 2 }) + line([[6, 12], [38, 13]], { stroke: "#2c3418", sw: 1 })));
  save("environments/outside/floating_bottle.svg", svg(44, 22, R(6, 7, 26, 10, "#b9d5dc", { sw: 2 }) + R(32, 9, 6, 6, P.blue, { sw: 2 }) + line([[0, 18], [44, 18]], { stroke: P.floodL, sw: 1.5 })));
  save("environments/outside/floating_chair.svg", svg(70, 40, shape([[8, 18], [58, 14], [62, 26], [10, 30]], "#c9603e", { sw: 2.5 }) + R(14, 4, 36, 12, "#c9603e", { sw: 2.5 }) + line([[0, 30], [70, 30]], { stroke: P.floodL, sw: 1.5 })));

  // ---- survivor status icons (32x32) shown above heads and in the journal
  seed = 1600;
  const bubble = (body) => svg(32, 32, E(16, 16, 14, 14, P.cream, { sw: 2.5 }) + body);
  save("ui/status/thirst.svg", bubble(shape([[16, 6], [23, 17], [16, 25], [9, 17]], P.blueL, { sw: 2 }) + line([[13, 14], [16, 19]], { stroke: P.ink, sw: 1.5 })));
  save("ui/status/hunger.svg", bubble(shape([[7, 15], [25, 15], [21, 24], [11, 24]], P.brownL, { sw: 2 }) + line([[11, 11], [14, 7]], { sw: 1.5 }) + line([[17, 11], [20, 7]], { sw: 1.5 })));
  save("ui/status/sick.svg", bubble(R(14, 6, 5, 16, "#f3efe3", { sw: 2 }) + E(16.5, 23, 4.5, 4.5, P.red, { sw: 2 }) + R(15.5, 13, 2, 9, P.red, { sw: 0.5 })));
  save("ui/status/injured.svg", bubble(`<g transform="rotate(-35 16 16)">` + R(5, 12, 22, 8, "#e6c9a2", { sw: 2 }) + R(12, 12, 8, 8, "#f3e6cf", { sw: 1.5 }) + `</g>` + E(22, 10, 2, 2, P.red, { stroke: "none" })));
  save("ui/status/away.svg", bubble(line([[8, 24], [24, 8]], { stroke: P.brown, sw: 3.5 }) + E(23, 9, 4, 6, P.brownL, { sw: 2 })));
  save("ui/status/dead.svg", bubble(shape([[11, 25], [11, 12], [16, 7], [21, 12], [21, 25]], "#9aa0a0", { sw: 2 }) + line([[14, 15], [18, 15]], { sw: 1.5 }) + line([[16, 12], [16, 20]], { sw: 1.5 })));
}


// ============================================================ PART 2b ART
// Skies per time of day, storm clouds, one mid-ground set per location, voyage obstacles.
// Every mid-ground image: bottom edge = waterline, ~620 px wide (the visible area left of the journal).

const WATERLINE = (w, y) => fillR(0, y, w, 400, "#2a4a4c", 0.85) + line([[0, y], [w, y]], { stroke: "#6b9a96", sw: 2, op: 0.7 });

function part2bArt() {
  // ---- skies (1280x440)
  const sky = (name, stops, extra = "") => {
    const defs = `<linearGradient id="s" x1="0" y1="0" x2="0" y2="1">${stops.map(([o, c]) => `<stop offset="${o}" stop-color="${c}"/>`).join("")}</linearGradient>`;
    save(`backgrounds/sky_${name}.svg`, svg(1280, 440, fillR(0, 0, 1280, 440, "url(#s)") + extra, defs));
  };
  seed = 1700;
  let clouds = (c, op, n = 12) => { let s = ""; for (let i = 0; i < n; i++) s += E(rnd() * 1300, 40 + rnd() * 240, 110 + rnd() * 170, 16 + rnd() * 22, c, { stroke: "none", op }); return s; };
  sky("dawn", [[0, "#34405e"], [0.55, "#b98a93"], [0.85, "#f0b57d"], [1, "#f6d3a0"]], E(330, 410, 70, 40, "#fff0c8", { stroke: "none", op: 0.55 }) + clouds("#7d6f86", 0.45));
  seed = 1701;
  sky("day", [[0, "#7f939f"], [0.6, "#aebbc0"], [1, "#d3d8d4"]], clouds("#8d989c", 0.5, 16));
  seed = 1702;
  sky("dusk", [[0, "#2a2846"], [0.5, "#8e4d63"], [0.82, "#e0844b"], [1, "#f0b66a"]], E(900, 420, 80, 46, "#ffd08a", { stroke: "none", op: 0.6 }) + clouds("#4b3550", 0.55));
  seed = 1703;
  let s = "";
  for (let i = 0; i < 22; i++) s += E(rnd() * 1320, 10 + rnd() * 230, 120 + rnd() * 200, 26 + rnd() * 34, i % 3 ? "#262a33" : "#3a3f4a", { stroke: "none", op: 0.8 });
  for (let i = 0; i < 8; i++) s += E(rnd() * 1300, 30 + rnd() * 180, 160, 22, "#4b5260", { stroke: "none", op: 0.35 });
  save("backgrounds/storm_clouds.svg", svg(1280, 300, s));

  // ---- temple: ubosot hall + white stupa, half under water (620x300)
  seed = 1710;
  s = E(470, 120, 70, 60, "#2f4a32", { sw: 2.5 }) + E(520, 96, 50, 44, "#38573a", { sw: 2.5 }) + R(488, 150, 12, 120, "#4a3626", { sw: 2 }); // bodhi tree
  s += shape([[60, 300], [180, 300], [170, 240], [70, 240]], "#e6e1d4") + shape([[80, 240], [160, 240], [150, 190], [90, 190]], "#e6e1d4") + shape([[100, 190], [140, 190], [124, 90], [116, 90]], "#e6e1d4") + E(120, 86, 6, 8, P.gold, { sw: 2 }); // stupa
  s += R(230, 170, 260, 130, "#e9e3d3") + hatch(236, 176, 240, 110, 10, { op: 0.15 });
  for (const x of [262, 312, 362, 412]) s += R(x, 196, 22, 60, "#4a3a2c", { sw: 2 }) + shape([[x, 196], [x + 22, 196], [x + 11, 184]], P.gold, { sw: 1.5 });
  s += shape([[210, 172], [510, 172], [440, 108], [280, 108]], "#a3452f") + shape([[240, 118], [480, 118], [420, 64], [300, 64]], "#b5533a") + shape([[280, 70], [440, 70], [360, 26]], "#4b6b3a");
  for (const [x, y] of [[210, 172], [510, 172], [240, 118], [480, 118], [360, 26]]) s += line([[x, y], [x + (x < 360 ? -10 : x > 360 ? 10 : 0), y - 18]], { stroke: P.gold, sw: 3.5 });
  s += line([[210, 172], [510, 172]], { stroke: P.gold, sw: 3 }) + line([[240, 118], [480, 118]], { stroke: P.gold, sw: 2.5 });
  s += WATERLINE(620, 252);
  save("backgrounds/loc_temple.svg", svg(620, 300, s));

  // ---- market: row of two-storey shophouses (signs are Labels in the scene) (620x270)
  seed = 1720;
  s = "";
  const tones = ["#b9b2a2", "#a89d87", "#c2b8a1", "#9fa39a"];
  for (let i = 0; i < 4; i++) {
    const x = 20 + i * 148;
    s += R(x, 40, 148, 230, tones[i]) + R(x + 6, 46, 136, 8, "#7d7566", { sw: 1.5 });
    s += R(x + 18, 70, 48, 44, "#3c4a52", { sw: 2 }) + R(x + 82, 70, 48, 44, "#3c4a52", { sw: 2 }) + R(x + 10, 118, 128, 6, "#6d6658", { sw: 1.5 });
    s += R(x + 10, 132, 128, 30, ["#3c5a7a", "#8a3a2e", "#3e6a4a", "#a0782a"][i], { sw: 2.5 }); // sign board
    for (let k = 0; k < 9; k++) s += line([[x + 12 + k * 14, 172], [x + 12 + k * 14, 270]], { stroke: "#6d6658", sw: 1.2, op: 0.7 }); // steel shutters
    s += hatch(x + 6, 50, 130, 60, 4, { op: 0.15 });
  }
  s += shape([[16, 128], [612, 128], [604, 136], [24, 136]], "#5a5246", { sw: 2 });
  s += WATERLINE(620, 205);
  save("backgrounds/loc_market.svg", svg(620, 270, s));

  // ---- field: open water, treetops, a sala pavilion, poles going away (620x210)
  seed = 1730;
  s = "";
  for (const [x, r] of [[60, 34], [150, 26], [420, 30], [560, 40], [600, 24]]) s += E(x, 176 - r * 0.5, r, r * 0.7, "#35503a", { sw: 2.5 });
  for (const [x, h] of [[200, 120], [300, 90], [380, 70], [440, 56]]) s += R(x, 190 - h, 5, h, "#5b5249", { sw: 1.5 }) + R(x - 10, 196 - h, 26, 3, "#5b5249", { sw: 1 });
  s += line([[203, 76], [302, 104], [383, 124], [443, 138]], { stroke: "#3b3530", sw: 1.4 });
  s += shape([[230, 150], [350, 150], [320, 116], [260, 116]], "#7a3e2c") + R(244, 150, 6, 40, "#5b4636", { sw: 2 }) + R(330, 150, 6, 40, "#5b4636", { sw: 2 }) + line([[290, 116], [290, 100]], { stroke: P.gold, sw: 3 });
  s += WATERLINE(620, 178);
  save("backgrounds/loc_field.svg", svg(620, 210, s));

  // ---- highway: bridge with a rescue tent and an army truck on top (620x280)
  seed = 1740;
  s = "";
  for (const x of [70, 250, 430, 590]) s += R(x, 150, 26, 130, "#9a9a92", { sw: 2.5 }) + fillR(x + 3, 154, 6, 120, "#fff", 0.12);
  s += R(0, 120, 620, 34, "#b4b3aa") + line([[0, 128], [620, 128]], { stroke: "#7e7d76", sw: 1.5 });
  for (let x = 6; x < 620; x += 24) s += R(x, 96, 4, 24, "#8d8c85", { sw: 1 });
  s += line([[0, 100], [620, 100]], { stroke: "#8d8c85", sw: 3 });
  s += shape([[300, 120], [380, 120], [380, 82], [340, 62], [300, 82]], "#e8eef2") + shape([[300, 82], [340, 62], [380, 82]], "#3c6aa0", { sw: 2.5 }) + R(328, 96, 24, 24, "#3c6aa0", { sw: 2 }); // relief tent
  s += R(420, 70, 110, 50, "#5c6640") + R(530, 84, 44, 36, "#4c5536") + R(538, 90, 26, 14, "#a9c0c8", { sw: 1.5 }); // army truck
  s += E(450, 122, 12, 12, P.char) + E(510, 122, 12, 12, P.char) + E(556, 122, 12, 12, P.char);
  for (const x of [200, 222, 396]) s += E(x, 104, 5, 6, "#3a3a3a", { sw: 1.5 }) + R(x - 5, 108, 10, 12, "#4d5a6a", { sw: 1.5 }); // people
  s += R(110, 40, 6, 80, "#6d6d68", { sw: 2 }) + R(76, 40, 74, 30, "#2f6a44", { sw: 2.5 }); // green road sign (text = Label)
  s += WATERLINE(620, 236);
  save("backgrounds/loc_highway.svg", svg(620, 280, s));

  // ---- voyage obstacles
  seed = 1750;
  s = shape([[6, 26], [150, 16], [156, 30], [10, 40]], "#5b3f2a") + E(12, 33, 7, 8, "#7a5638") + line([[30, 25], [130, 20]], { stroke: "#3a2718", sw: 1.5 }) + line([[90, 20], [104, 4]], { stroke: "#5b3f2a", sw: 4 }) + line([[0, 40], [160, 40]], { stroke: P.floodL, sw: 2 });
  save("environments/outside/log.svg", svg(160, 46, s));
  s = line([[10, 60], [70, 30]], { stroke: "#4a3626", sw: 6 }) + line([[40, 46], [30, 12]], { stroke: "#4a3626", sw: 4 }) + E(30, 12, 18, 12, "#3e5a34") + E(76, 26, 22, 14, "#4b6b3a") + line([[0, 62], [100, 62]], { stroke: P.floodL, sw: 2 });
  save("environments/outside/branch.svg", svg(100, 68, s));
  s = R(10, 20, 80, 44, "#c9603e") + R(16, 10, 68, 12, "#c9603e", { sw: 2.5 }) + E(50, 42, 12, 8, "#8a3a2e", { sw: 2 }) + line([[0, 62], [100, 62]], { stroke: P.floodL, sw: 2 });
  save("environments/outside/fridge_float.svg", svg(100, 70, R(14, 6, 60, 58, "#dfe3e0") + R(20, 12, 48, 20, "#c8cfcc", { sw: 2 }) + line([[0, 60], [90, 60]], { stroke: P.floodL, sw: 2 })));
}


// ============================================================ PART 2c ART
// Family portraits (inventory icons) + intro cutscene pieces (TV, news screen).
function part2cArt() {
  // ---- family member icons (64x64): head & shoulders cropped from the seated art
  for (const who of ["mother", "sister", "grandpa"]) {
    seed = 1200 + 5;
    const body = seated(who, "idle0");
    const zoom = who === "sister" ? 1.25 : 1.0;
    save(`items/family_${who}.svg`, svg(64, 64,
      `<clipPath id="c"><rect x="0" y="0" width="64" height="64" rx="10"/></clipPath>` +
      `<g clip-path="url(#c)"><rect x="0" y="0" width="64" height="64" fill="${P.beigeL}"/>` +
      `<g transform="translate(${32 - 48 * zoom} ${-10 - (zoom - 1) * 70}) scale(${zoom})">${body}</g></g>` +
      `<rect x="1.5" y="1.5" width="61" height="61" rx="10" fill="none" stroke="${P.ink}" stroke-width="3"/>`));
  }

  // ---- back of a CRT TV glowing in a dark room (360x210)
  seed = 1800;
  let s = E(180, 40, 190, 60, "#9fc4ff", { stroke: "none", op: 0.25 }) + E(180, 50, 130, 40, "#cfe2ff", { stroke: "none", op: 0.25 });
  s += shape([[70, 46], [290, 46], [312, 168], [48, 168]], "#2b2a2e", { sw: 3.5 }) + shape([[110, 20], [250, 20], [290, 46], [70, 46]], "#3a393e", { sw: 3 });
  for (let i = 0; i < 7; i++) s += line([[120 + i * 18, 70], [116 + i * 18, 120]], { stroke: "#18171a", sw: 4 });
  s += line([[300, 150], [340, 190], [360, 192]], { stroke: P.ink, sw: 4 });
  s += R(0, 166, 360, 44, P.brownD, { sw: 3 }) + fillR(4, 170, 352, 6, "#fff", 0.08);
  save("cutscene/tv_back.svg", svg(360, 210, s));

  // ---- CRT bezel filling the screen, with a hole for the picture (1280x720)
  seed = 1801;
  const hole = "M168 92 Q164 86 176 84 L1104 84 Q1116 86 1112 92 L1120 610 Q1122 624 1108 626 L172 626 Q158 624 160 610 Z";
  s = `<path d="M0 0 H1280 V720 H0 Z ${hole}" fill="#3b3631" fill-rule="evenodd" stroke="${P.ink}" stroke-width="5"/>`;
  s += `<path d="${hole}" fill="none" stroke="#1d1a17" stroke-width="18"/>`;
  s += fillR(0, 0, 1280, 30, "#fff", 0.05) + grime(20, 640, 1240, 70, 40, "#000", 0.25);
  s += E(1190, 660, 22, 22, "#2a2622", { sw: 3 }) + E(1120, 660, 22, 22, "#2a2622", { sw: 3 }) + R(560, 650, 160, 26, "#2a2622", { sw: 2.5 });
  s += E(1060, 664, 6, 6, "#e2583e", { stroke: "none" });
  save("cutscene/crt_frame.svg", svg(1280, 720, s));

  // ---- glass: dark curved edges + scanlines (960x544, over the picture)
  let lines = "";
  for (let y = 0; y < 544; y += 4) lines += `<rect x="0" y="${y}" width="960" height="1.4" fill="#000" opacity="0.18"/>`;
  save("cutscene/crt_glass.svg", svg(960, 544, lines + `<rect x="0" y="0" width="960" height="544" fill="url(#g)"/>`,
    `<radialGradient id="g" cx="0.5" cy="0.5" r="0.75"><stop offset="0.55" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.75"/></radialGradient>`));

  // ---- news map of Ubon: land + Mun & Chi rivers (520x360); place labels are Labels in the scene
  seed = 1802;
  s = fillR(0, 0, 520, 360, "#1e3a5c");
  s += shape([[30, 60], [180, 30], [330, 50], [480, 40], [500, 150], [470, 300], [300, 330], [120, 320], [40, 230]], "#c9b98f", { sw: 3 });
  s += hatch(60, 70, 400, 230, 30, { color: "#8a7a58", op: 0.25 });
  s += line([[20, 170], [120, 190], [200, 170], [290, 200], [380, 190], [500, 210]], { stroke: "#3c79b8", sw: 7 }); // Mun
  s += line([[120, 60], [180, 110], [250, 140], [290, 200]], { stroke: "#3c79b8", sw: 6 }); // Chi joins the Mun
  s += E(330, 198, 9, 9, "#e2583e", { sw: 3 });
  save("cutscene/news_map.svg", svg(520, 360, s));
  s = E(300, 190, 150, 70, "#3f8de0", { stroke: "#9fd0ff", sw: 3, op: 0.75 }) + E(200, 170, 90, 40, "#3f8de0", { stroke: "none", op: 0.6 }) + E(420, 210, 80, 40, "#3f8de0", { stroke: "none", op: 0.6 });
  save("cutscene/news_flood.svg", svg(520, 360, s));

  // ---- news anchor (300x320)
  seed = 1803;
  s = shape([[20, 320], [40, 220], [110, 190], [190, 190], [260, 220], [280, 320]], "#2b3a5a");
  s += shape([[120, 190], [150, 250], [180, 190]], "#f0eee6", { sw: 2.5 }) + shape([[143, 198], [157, 198], [160, 260], [150, 274], [140, 260]], "#a3352a", { sw: 2 });
  s += R(132, 160, 36, 34, P.skin, { sw: 2.5 }) + E(150, 120, 46, 52, P.skin);
  s += shape([[104, 120], [104, 90], [120, 70], [150, 62], [182, 70], [198, 92], [196, 120], [184, 96], [150, 88], [116, 98]], "#1d1a19", { sw: 2.5 });
  s += E(132, 124, 4, 5, P.ink, { stroke: "none" }) + E(168, 124, 4, 5, P.ink, { stroke: "none" }) + line([[124, 110], [140, 108]], { sw: 2.5 }) + line([[160, 108], [176, 110]], { sw: 2.5 });
  s += line([[138, 150], [162, 150]], { sw: 2.5 }) + E(150, 136, 4, 3, P.skinD, { stroke: "none", op: 0.6 });
  save("cutscene/anchor.svg", svg(300, 320, s));
}

floorAtlas();
walls();
wallDecor();
allFurniture();
outside();
items();
character();
rescueBoat();
part2Art();
part2bArt();
part2cArt();
ui();
touchUi();
glyphIcons();
backgrounds();
console.log(`generated ${count} svg files`);
