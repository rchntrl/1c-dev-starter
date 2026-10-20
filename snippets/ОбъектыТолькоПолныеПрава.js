const fs = require('fs'), path = require('path');
// Объекты конфигурации, права на которые есть только у роли ПолныеПрава.
// Запуск из корня проекта: node snippets/ОбъектыТолькоПолныеПрава.js [conf]
const conf = process.argv[2] || 'conf';
const rolesDir = path.join(conf, 'Roles');
const FULL = 'ПолныеПрава';

// top-level objects from Configuration.xml
const cfg = fs.readFileSync(path.join(conf, 'Configuration.xml'), 'utf8');
const co = cfg.slice(cfg.indexOf('<ChildObjects>'), cfg.indexOf('</ChildObjects>'));
const all = [...co.matchAll(/<(\w+)>([^<]+)<\/\1>/g)].map(m => `${m[1]}.${m[2]}`);

const granted = new Map(); // top-level object -> Set(roles with any true right)
const fullDenied = new Set();
const typesInRights = new Set();
for (const role of fs.readdirSync(rolesDir)) {
  const f = path.join(rolesDir, role, 'Ext', 'Rights.xml');
  if (!fs.existsSync(f)) continue;
  const x = fs.readFileSync(f, 'utf8');
  for (const m of x.matchAll(/<object>\s*<name>([^<]+)<\/name>([\s\S]*?)<\/object>/g)) {
    const parts = m[1].split('.');
    const top = parts.slice(0, 2).join('.');
    typesInRights.add(parts[0]);
    const anyTrue = /<value>true<\/value>/.test(m[2]);
    if (anyTrue) {
      if (!granted.has(top)) granted.set(top, new Set());
      granted.get(top).add(role);
    } else if (role === FULL && parts.length === 2) fullDenied.add(top);
  }
}

const res = {};
for (const o of all) {
  const t = o.split('.')[0];
  if (!typesInRights.has(t) || t === 'Configuration') continue;
  const g = granted.get(o);
  const others = g ? [...g].filter(r => r !== FULL) : [];
  if (others.length === 0) (res[t] ||= []).push(o.split('.')[1] + (fullDenied.has(o) ? ' (в ПолныеПрава есть явные запреты)' : ''));
}
let n = 0;
for (const t of Object.keys(res).sort()) {
  console.log(`\n## ${t} (${res[t].length})`);
  for (const o of res[t].sort()) console.log('- ' + o), n++;
}
console.log(`\nИтого: ${n}`);
