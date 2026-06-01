// Fix N°76c · alinear apiFetch helpers a token keys de useAuth (inv_token / pur_token)
const fs = require('fs');
const path = require('path');

const FIXES = [
  {
    files: [
      'C:/Users/Administrator/Desktop/Imperium_Inventory/client/src/pages/Almacenes.jsx',
      'C:/Users/Administrator/Desktop/Imperium_Inventory/client/src/pages/Movimientos.jsx',
      'C:/Users/Administrator/Desktop/Imperium_Inventory/client/src/pages/Lotes.jsx',
      'C:/Users/Administrator/Desktop/Imperium_Inventory/client/src/pages/Proveedores.jsx',
      'C:/Users/Administrator/Desktop/Imperium_Inventory/client/src/pages/ReorderRules.jsx',
    ],
    tokenKey: 'inv_token',
    oldStorageKey: 'imperium_inv_tokens',
  },
  {
    files: [
      'C:/Users/Administrator/Desktop/Imperium_Purchasing/client/src/pages/Almacenes.jsx', // may not exist
      'C:/Users/Administrator/Desktop/Imperium_Purchasing/client/src/pages/Movimientos.jsx',
      'C:/Users/Administrator/Desktop/Imperium_Purchasing/client/src/pages/Lotes.jsx',
      'C:/Users/Administrator/Desktop/Imperium_Purchasing/client/src/pages/Proveedores.jsx',
      'C:/Users/Administrator/Desktop/Imperium_Purchasing/client/src/pages/ReorderRules.jsx',
      'C:/Users/Administrator/Desktop/Imperium_Purchasing/client/src/pages/OrdenesCompra.jsx',
      'C:/Users/Administrator/Desktop/Imperium_Purchasing/client/src/pages/NuevaOC.jsx',
      'C:/Users/Administrator/Desktop/Imperium_Purchasing/client/src/pages/DetalleOC.jsx',
      'C:/Users/Administrator/Desktop/Imperium_Purchasing/client/src/pages/ColaAprobacion.jsx',
      'C:/Users/Administrator/Desktop/Imperium_Purchasing/client/src/pages/Recepciones.jsx',
    ],
    tokenKey: 'pur_token',
    oldStorageKey: 'imperium_pur_tokens',
  },
];

let totalChanged = 0;
for (const fix of FIXES) {
  for (const f of fix.files) {
    if (!fs.existsSync(f)) continue;
    let c = fs.readFileSync(f, 'utf8');
    const before = c;
    // Replace JSON.parse pattern with simple getItem
    c = c.replace(
      new RegExp(`const tokens = JSON\\.parse\\(localStorage\\.getItem\\('${fix.oldStorageKey}'\\) \\|\\| '\\{\\}'\\);`, 'g'),
      `const tok = localStorage.getItem('${fix.tokenKey}');`
    );
    // Replace tokens.accessToken header guard
    c = c.replace(
      /\.\.\.\(tokens\.accessToken && \{ Authorization: `Bearer \$\{tokens\.accessToken\}` \}\)/g,
      '...(tok && { Authorization: `Bearer ${tok}` })'
    );
    if (c !== before) {
      fs.writeFileSync(f, c);
      console.log(`  ✅ ${path.basename(f)} → ${fix.tokenKey}`);
      totalChanged++;
    } else {
      console.log(`  ↻ ${path.basename(f)} (no changes)`);
    }
  }
}
console.log(`\nTotal modified: ${totalChanged}`);
