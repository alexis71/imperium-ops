// Sync REAL data desde KP demo1-vet → Imperium Inventory + Purchasing + CRM
// Reemplaza data sintética por linkage real con KP catalogItems/products/owners
// Idempotente · re-run safe
//
// Usage: node Desktop/_ops/sync-kp-to-imperium-real.js

const cp = require('child_process');
const KP_TENANT = '777f5360-8ff3-45f7-9316-bdd241e1ea90';
const KP_SLUG = 'demo1-vet';

function loadPrisma(dir) {
  const ppath = cp.execSync(`find "C:/Users/Administrator/Desktop/${dir}" -name "@prisma" -type d 2>/dev/null | head -1`, { shell: 'C:/Program Files/Git/bin/bash.exe' }).toString().trim();
  return require(ppath + '/client').PrismaClient;
}

async function syncToInv(kpData) {
  console.log('\n═══ Sync KP → Imperium_Inventory · productRefs reales ═══');
  const Inv = loadPrisma('Imperium_Inventory');
  const p = new Inv();
  const tenant = await p.tenant.findFirst({ where: { slug: KP_SLUG } });
  if (!tenant) { console.log('  ❌ Inv tenant demo1-vet no existe'); await p.$disconnect(); return; }

  // 1. Sync warehouses · alinear con KP warehouses (Almacén Norte/general/Farmacia)
  const invWhs = await p.warehouse.findMany({ where: { tenantId: tenant.id } });
  console.log('  Inv warehouses actuales:', invWhs.length);
  // Rename Inv warehouses to match KP if needed
  const renameMap = [
    { from: 'Refrigerador vacunas', to: 'Refrigerador vacunas', branchRef: `kp:${KP_SLUG}:${kpData.branches[0]?.id || ''}` },
    { from: 'Bodega principal',     to: 'Almacén general',      branchRef: `kp:${KP_SLUG}:${kpData.branches[1]?.id || ''}` },
    { from: 'Farmacia mostrador',   to: 'Farmacia',             branchRef: `kp:${KP_SLUG}:${kpData.branches[1]?.id || ''}` },
  ];
  for (const r of renameMap) {
    const wh = invWhs.find(w => w.name === r.from);
    if (wh && wh.name !== r.to) {
      await p.warehouse.update({ where: { id: wh.id }, data: { name: r.to, branchRef: r.branchRef } });
    } else if (wh && !wh.branchRef?.includes(r.branchRef.split(':')[2])) {
      await p.warehouse.update({ where: { id: wh.id }, data: { branchRef: r.branchRef } });
    }
  }
  const refrig = invWhs.find(w => w.type === 'refrigerated') || invWhs[0];
  const general = invWhs.find(w => w.name === 'Almacén general' || w.type === 'general');
  const farmacia = invWhs.find(w => w.name === 'Farmacia' || w.type === 'retail');

  // 2. Sync KP products → Inv stockMovements con productRef real
  let prodSynced = 0;
  for (const prod of kpData.products) {
    const productRef = `kp:${KP_SLUG}:${prod.id}`;
    // Si ya existe movement IN inicial para este productRef · skip
    const existing = await p.stockMovement.findFirst({ where: { tenantId: tenant.id, productRef, reference: 'KP-SYNC' } });
    if (existing) continue;
    // Initial stock = 10-50 random based on product type
    const initialStock = Math.floor(Math.random() * 30) + 10;
    const wh = prod.name?.toLowerCase().includes('vacuna') ? refrig : (prod.name?.toLowerCase().includes('alimento') || prod.name?.toLowerCase().includes('canin') || prod.name?.toLowerCase().includes('plan') ? general : farmacia);
    // Estimar costo
    const cost = prod.name?.toLowerCase().includes('royal canin') ? 1850
               : prod.name?.toLowerCase().includes('vacuna') ? 280
               : prod.name?.toLowerCase().includes('amoxicilina') ? 145
               : prod.name?.toLowerCase().includes('shampoo') ? 320
               : prod.name?.toLowerCase().includes('jeringa') ? 4.5
               : prod.name?.toLowerCase().includes('collar') ? 95
               : prod.name?.toLowerCase().includes('drontal') || prod.name?.toLowerCase().includes('desparasitante') ? 180
               : 100;
    await p.stockMovement.create({
      data: {
        tenantId: tenant.id, movementType: 'IN',
        productRef, productName: prod.name || '(sin nombre)',
        quantity: initialStock, unit: 'unidad',
        unitCostMxn: cost,
        toWarehouseId: wh.id,
        reference: 'KP-SYNC', reason: 'Sync KP product → Inv · stock inicial cross-vertical',
      },
    });
    prodSynced++;
  }
  console.log('  ✅ KP products sincronizados a Inv como movements:', prodSynced);

  // 3. Sync KP catalogItems kind=insumo → Inv reorder rules
  let rulesSynced = 0;
  for (const ci of kpData.catalogItems.filter(c => c.kind === 'insumo')) {
    const productRef = `kp:${KP_SLUG}:catalog-${ci.id}`;
    const existing = await p.reorderRule.findFirst({ where: { tenantId: tenant.id, productRef } });
    if (existing) continue;
    // También crear stock inicial
    const stockExists = await p.stockMovement.findFirst({ where: { tenantId: tenant.id, productRef } });
    if (!stockExists) {
      const cost = ci.name?.toLowerCase().includes('jeringa') ? 4.5
                : ci.name?.toLowerCase().includes('amoxicilina') ? 145
                : ci.name?.toLowerCase().includes('vacuna') ? 280
                : ci.name?.toLowerCase().includes('gasa') ? 30
                : ci.name?.toLowerCase().includes('collar') ? 95
                : ci.name?.toLowerCase().includes('suero') ? 65
                : ci.name?.toLowerCase().includes('catéter') ? 120
                : 50;
      await p.stockMovement.create({
        data: {
          tenantId: tenant.id, movementType: 'IN',
          productRef, productName: ci.name,
          quantity: 25, unit: 'unidad', unitCostMxn: cost,
          toWarehouseId: farmacia.id,
          reference: 'KP-CATALOG-SYNC', reason: 'Sync KP catalogItem (insumo) · stock inicial',
        },
      });
    }
    await p.reorderRule.create({
      data: {
        tenantId: tenant.id, productRef, productName: ci.name,
        warehouseId: farmacia.id, minStock: 5, reorderQty: 20, leadTimeDays: 5,
        preferredSupplierRef: 'Laboratorios Bayer · División Animal',
      },
    });
    rulesSynced++;
  }
  console.log('  ✅ KP catalogItems → Inv reorder rules:', rulesSynced);

  const finalProd = await p.stockMovement.groupBy({ by: ['productRef'], where: { tenantId: tenant.id } });
  const finalMov = await p.stockMovement.count({ where: { tenantId: tenant.id } });
  const finalRule = await p.reorderRule.count({ where: { tenantId: tenant.id } });
  console.log('  Estado final Inv · productRefs únicos=' + finalProd.length + ' · movements=' + finalMov + ' · reorder rules=' + finalRule);
  await p.$disconnect();
}

async function syncToCrm(kpData) {
  console.log('\n═══ Sync KP owners → Imperium_CRM customers ═══');
  const Crm = loadPrisma('Imperium_CRM');
  const p = new Crm();
  const tenant = await p.tenant.findFirst({ where: { slug: 'crm-clinica-veterinaria-demo-1-vet-kp' } });
  if (!tenant) { console.log('  ❌ CRM tenant no existe'); await p.$disconnect(); return; }

  let custSynced = 0;
  for (const owner of kpData.owners) {
    const externalRef = `kp:${KP_SLUG}:${owner.id}`;
    const existing = await p.customer.findFirst({ where: { tenantId: tenant.id, externalRef } });
    if (existing) continue;
    await p.customer.create({
      data: {
        tenantId: tenant.id, type: 'person',
        firstName: owner.firstName || owner.name?.split(' ')[0] || 'Cliente',
        lastName: owner.lastName || owner.name?.split(' ').slice(1).join(' ') || '',
        email: owner.email || null,
        phone: owner.phone || null,
        externalRef, source: 'kp:owner',
        tags: JSON.stringify(['paciente-kp']),
        active: true,
      },
    });
    custSynced++;
  }
  const total = await p.customer.count({ where: { tenantId: tenant.id } });
  console.log('  ✅ KP owners sincronizados a CRM:', custSynced, '· total ahora:', total);
  await p.$disconnect();
}

async function readKpData() {
  console.log('═══ Leyendo data real desde KP demo1-vet ═══');
  const Kp = loadPrisma('Kompaws');
  const kp = new Kp();
  const data = {
    branches:    await kp.branch.findMany({ where: { tenantId: KP_TENANT } }),
    catalogItems: await kp.catalogItem.findMany({ where: { tenantId: KP_TENANT } }),
    products:    await kp.product.findMany({ where: { tenantId: KP_TENANT } }),
    warehouses:  await kp.warehouse.findMany({ where: { tenantId: KP_TENANT } }),
    owners:      await kp.owner.findMany({ where: { tenantId: KP_TENANT } }),
  };
  console.log('  · ' + data.branches.length + ' branches · ' + data.catalogItems.length + ' catalogItems · ' + data.products.length + ' products · ' + data.warehouses.length + ' warehouses · ' + data.owners.length + ' owners');
  await kp.$disconnect();
  return data;
}

(async () => {
  console.log('\n═══════════════════════════════════════════════════════════════');
  console.log('  Imperium · Sync REAL data desde KP demo1-vet (N°77 close cont.)');
  console.log('═══════════════════════════════════════════════════════════════');
  try {
    const kpData = await readKpData();
    await syncToInv(kpData);
    await syncToCrm(kpData);
    console.log('\n  ✅ Sync completo · Inv y CRM ahora referencian data real de KP');
    console.log('  productRef formato: kp:demo1-vet:<kpItemId>');
  } catch (e) {
    console.error('❌ Sync falló:', e.message, e.stack);
    process.exit(1);
  }
})();
