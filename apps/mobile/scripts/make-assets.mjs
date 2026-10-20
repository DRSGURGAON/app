// Generates the app icon, adaptive icon and splash artwork (original design: a shopping basket on army green).
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const sharp = require('../../api/node_modules/sharp');
const GREEN = '#1B5E20', SAFFRON = '#F9A825';
const basket = (scale = 1, color = '#FFFFFF', mark = GREEN) => `
  <g transform="translate(512 540) scale(${scale}) translate(-512 -512)">
    <path d="M300 420 L724 420 L690 700 Q684 740 644 740 L380 740 Q340 740 334 700 Z" fill="${color}"/>
    <path d="M360 420 C360 300 664 300 664 420" fill="none" stroke="${color}" stroke-width="42" stroke-linecap="round"/>
    <rect x="270" y="396" width="484" height="52" rx="26" fill="${color}"/>
    <circle cx="512" cy="590" r="62" fill="${SAFFRON}"/>
  </g>`;
const wrap = (inner, bg) => `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">${bg ? `<rect width="1024" height="1024" fill="${bg}"/>` : ''}${inner}</svg>`;
const out = (name, svg, size = 1024) => sharp(Buffer.from(svg)).resize(size, size).png().toFile(`assets/${name}`);
await out('icon.png', wrap(`<rect y="800" width="1024" height="60" fill="${SAFFRON}"/>` + basket(1), GREEN));
await out('adaptive-icon.png', wrap(basket(0.78)));          // foreground only; background colour comes from app config
await out('splash-icon.png', wrap(basket(1, GREEN)));
await out('favicon.png', wrap(basket(1), GREEN), 48);
console.log('assets written');
