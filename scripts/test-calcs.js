#!/usr/bin/env node
// Pruebas de los cálculos de Cromat: vacíos, cero, NaN e Infinity.
// Espejo de las fórmulas endurecidas en index.html.

function finiteNum(n, def) {
  n = parseFloat(n);
  return isFinite(n) ? n : def;
}
function usd(n) {
  n = +n;
  if (!isFinite(n)) n = 0;
  return '$' + n.toFixed(2);
}
function safeDiv(a, b, fallback) {
  if (!isFinite(a) || !isFinite(b) || b === 0) return fallback == null ? 0 : fallback;
  return a / b;
}
function clampPct(n, d) {
  n = finiteNum(n, d);
  return Math.max(0, Math.min(100, n));
}
function calcImpresion(vals) {
  var largo = finiteNum(vals.largo, 1);
  var ancho = finiteNum(vals.ancho, 1.6);
  var area = largo * ancho;
  var tkC = finiteNum(vals.tkC, 22), tkM = finiteNum(vals.tkM, 22), tkY = finiteNum(vals.tkY, 22), tkK = finiteNum(vals.tkK, 22);
  var tkProm = (tkC + tkM + tkY + tkK) / 4;
  var mlm2 = finiteNum(vals.mlm2, 6);
  var purga = finiteNum(vals.purga, 0);
  var tinta_m2 = tkProm / 1000 * mlm2 * (1 + purga / 100);
  var rp = finiteNum(vals.rp, 60), rl = finiteNum(vals.rl, 100);
  var papel_m2 = safeDiv(rp, rl * ancho, 0);
  var metrosVida = finiteNum(vals.metrosVida, 8000);
  var vimp = finiteNum(vals.vimp, 12000);
  var dep_ml = safeDiv(vimp, metrosVida, 0);
  var dep_m2 = safeDiv(dep_ml, ancho, 0);
  var sal = finiteNum(vals.sal, 200), gf = finiteNum(vals.gf, 250), otros = finiteNum(vals.otros, 0);
  var m2mes = finiteNum(vals.m2mes, 400);
  var mano_m2 = safeDiv(sal, m2mes, 0);
  var prorr_m2 = safeDiv(gf, m2mes, 0);
  var costo_m2 = tinta_m2 + papel_m2 + 0 + dep_m2 + mano_m2 + prorr_m2 + otros;
  var mgPct = finiteNum(vals.mgPct, 89);
  var ceoPct = clampPct(vals.ceoPct, 15);
  var operPct = clampPct(vals.operPct, 5);
  var negPct = Math.max(0, 100 - ceoPct - operPct);
  var impPct = clampPct(vals.impPct, 10);
  var gan_m2 = costo_m2 * mgPct / 100;
  var precio_m2 = costo_m2 + gan_m2;
  var imp_m2 = gan_m2 * impPct / 100;
  var gan_rep_m2 = gan_m2 - imp_m2;
  return {
    area: area, papel_m2: papel_m2, dep_ml: dep_ml, dep_m2: dep_m2, mano_m2: mano_m2,
    costo_m2: costo_m2, gan_m2: gan_m2, imp_m2: imp_m2, gan_rep_m2: gan_rep_m2,
    precio_m2: precio_m2, negPct: negPct, ceoPct: ceoPct, operPct: operPct,
    neg_m2: gan_rep_m2 * negPct / 100, ceo_m2: gan_rep_m2 * ceoPct / 100, oper_m2: gan_rep_m2 * operPct / 100
  };
}
function contaReparto(ing, costo, impPct, negPct, ceoPct, operPct) {
  ing = finiteNum(ing, 0);
  costo = finiteNum(costo, 0);
  impPct = clampPct(impPct, 10);
  negPct = clampPct(negPct, 80);
  ceoPct = clampPct(ceoPct, 15);
  operPct = clampPct(operPct, 5);
  var impuesto = ing * impPct / 100;
  var gan = ing - costo - impuesto;
  return {
    impuesto: impuesto, gan: gan,
    neg: gan * negPct / 100, ceo: gan * ceoPct / 100, oper: gan * operPct / 100,
    sumaPct: negPct + ceoPct + operPct
  };
}
function alimentarFondos(ingreso, costoPct, impPct, fondos) {
  ingreso = finiteNum(ingreso, 0);
  if (!(ingreso > 0)) return { aportes: [], base: 0 };
  costoPct = clampPct(costoPct, 0);
  impPct = clampPct(impPct, 10);
  var costo = ingreso * costoPct / 100;
  var impuesto = ingreso * impPct / 100;
  var base = Math.max(0, ingreso - costo - impuesto);
  return {
    base: base,
    aportes: fondos.map(function (f) {
      return { nombre: f.nombre, aporte: base * clampPct(f.pct, 0) / 100 };
    })
  };
}

var failed = 0;
function eq(name, got, exp, eps) {
  eps = eps == null ? 1e-9 : eps;
  var ok = typeof exp === 'string' ? got === exp : Math.abs(got - exp) <= eps;
  if (!ok) {
    failed++;
    console.error('FALLO ' + name + ': obtuve ' + got + ' esperado ' + exp);
  }
}

eq('usd NaN', usd(NaN), '$0.00');
eq('usd vacío', usd(''), '$0.00');
eq('usd Infinity', usd(Infinity), '$0.00');
eq('usd null', usd(null), '$0.00');
eq('finiteNum vacío', finiteNum('', 6), 6);
eq('finiteNum NaN', finiteNum('abc', 6), 6);
eq('finiteNum cero', finiteNum('0', 6), 0);
eq('safeDiv cero', safeDiv(10, 0, 0), 0);
eq('safeDiv NaN', safeDiv(10, NaN, 0), 0);

var z = calcImpresion({ largo: 0, ancho: 0, rl: 0, metrosVida: 0, m2mes: 0, rp: 60, vimp: 12000, sal: 200, gf: 250 });
eq('área 0×0', z.area, 0);
eq('papel con ancho 0', z.papel_m2, 0);
eq('depreciación vida 0', z.dep_ml, 0);
eq('mano m2mes 0', z.mano_m2, 0);
eq('costo finito con ceros', isFinite(z.costo_m2) ? 1 : 0, 1);

var okImp = calcImpresion({ largo: 1, ancho: 1.6, rl: 100, metrosVida: 8000, m2mes: 400, rp: 60, vimp: 12000, sal: 200, gf: 250, mgPct: 89, ceoPct: 15, operPct: 5, impPct: 10, tkC: 22, tkM: 22, tkY: 22, tkK: 22, mlm2: 6, purga: 0, otros: 0 });
eq('reparto 80', okImp.negPct, 80);
eq('reparto 15', okImp.ceoPct, 15);
eq('reparto 5', okImp.operPct, 5);
eq('impuesto sobre ganancia', Math.abs(okImp.imp_m2 - okImp.gan_m2 * 0.1) < 1e-9 ? 1 : 0, 1);
eq('neta = bruta − impuesto', Math.abs(okImp.gan_rep_m2 - (okImp.gan_m2 - okImp.imp_m2)) < 1e-9 ? 1 : 0, 1);
eq('80+15+5 de neta', Math.abs(okImp.neg_m2 + okImp.ceo_m2 + okImp.oper_m2 - okImp.gan_rep_m2) < 1e-9 ? 1 : 0, 1);

var r = contaReparto(1000, 350, 10, 80, 15, 5);
eq('conta impuesto 10% de 1000', r.impuesto, 100);
eq('conta neta 1000-350-100', r.gan, 550);
eq('conta negocio 80%', r.neg, 440);
eq('conta ceo 15%', r.ceo, 82.5);
eq('conta oper 5%', r.oper, 27.5);
var vacio = contaReparto('', '', 'x', '', NaN, Infinity);
eq('conta vacío ingreso', vacio.gan, 0);
eq('conta Infinity oper → 5 default clamp', vacio.operPct === undefined ? vacio.sumaPct >= 0 : 1, 1);

var f = alimentarFondos(1000, 35, 10, [{ nombre: 'Impuesto', pct: 10 }, { nombre: 'Caja', pct: 5 }]);
eq('fondos base neta 1000-350-100', f.base, 550);
eq('fondo 10% de neta', f.aportes[0].aporte, 55);
eq('fondo 5% de neta', f.aportes[1].aporte, 27.5);
var f0 = alimentarFondos(0, 35, 10, [{ nombre: 'X', pct: 10 }]);
eq('fondos ingreso 0', f0.base, 0);
eq('fondos ingreso 0 sin aportes', f0.aportes.length, 0);
var fnan = alimentarFondos(NaN, NaN, NaN, [{ nombre: 'X', pct: 'abc' }]);
eq('fondos NaN', fnan.base, 0);

if (failed) {
  console.error(failed + ' pruebas fallidas');
  process.exit(1);
}
console.log('OK: cálculos de cotizador, impuesto, 80/15/5 y fondos (vacío / 0 / NaN)');
