#!/usr/bin/env node
var fs = require('fs');
var path = require('path');
var file = path.join(__dirname, '..', 'index.html');
var url = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.VITE_SUPABASE_URL || '';
var key = process.env.SUPABASE_ANON_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || process.env.VITE_SUPABASE_ANON_KEY || '';
var html = fs.readFileSync(file, 'utf8');
if (url.indexOf('https://') === 0 && key) {
  html = html.replace(/var SB_URL='__SB_URL__'/, "var SB_URL='" + url.replace(/'/g, '') + "'");
  html = html.replace(/var SB_KEY='__SB_KEY__'/, "var SB_KEY='" + key.replace(/'/g, '') + "'");
  fs.writeFileSync(file, html);
  console.log('Supabase inyectado en index.html');
} else {
  console.log('Sin SUPABASE_URL / SUPABASE_ANON_KEY: la app sigue en modo local (se puede conectar desde Usuarios).');
}
