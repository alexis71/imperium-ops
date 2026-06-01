// Sync POs en Purchasing referenciando productos REALES de KP (catalogItems + products)
// Crea 4 POs de ejemplo · cada uno con 2-3 líneas que apuntan a kp:demo1-vet:<id>
// Idempotente

const cp = require('child_process');
const KP_SLUG = 'demo1-vet';
const KP_TENANT = '777f5360-8ff3-45f7-9316-bdd241e1ea90';

function loadPrisma(dir) {
  const ppath = cp.execSync(`find "C:/Users/Administrator/Desktop/${dir}" -name "@prisma" -type d 2>/dev/null | head -1`, { shell: 'C:/Program Files/Git/bin/bash.exe' }).toString().trim();
  return require(ppath + '/client').PrismaClient;
}

(async () => {
  console.log('\n═══ Sync POs Purchasing con productRefs reales KP ═══');

  const Kp = loadPrisma('Kompaws');
  const kp = new Kp();
  const products = await kp.product.findMany({ where: { tenantId: KP_TENANT } });
  const catalogItems = await kp.catalogItem.findMany({ where: { tenantId: KP_TENANT, kind: 'insumo' } });
  await kp.$disconnect();
  console.log('  KP products read:', products.length, '· catalogItems(insumo):', catalogItems.length);

  const Pur = loadPrisma('Imperium_Purchasing');
  const p = new Pur();
  const tenant = await p.tenant.findFirst({ where: { slug: KP_SLUG } });
  if (!tenant) { console.log('  ❌ Pur tenant demo1-vet no existe'); await p.$disconnect(); return; }

  // Suppliers (ya existen del seed)
  const suppliers = await p.supplier.findMany({ where: { tenantId: tenant.id } });
  const bayer = suppliers.find(s => s.name?.includes('Bayer'));
  const royal = suppliers.find(s => s.name?.includes('Royal Canin'));
  const dvnorte = suppliers.find(s => s.name?.includes('Norte'));
  const surtek = suppliers.find(s => s.name?.includes('Surtek'));

  // Helper · próximo número PO
  const year = new Date().getFullYear();
  async function nextNum() {
    const last = await p.purchaseOrder.findFirst({ where: { tenantId: tenant.id, poNumber: { startsWith: `PO-${year}-` } }, orderBy: { poNumber: 'desc' } });
    return `PO-${year}-${String((last ? parseInt(last.poNumber.split('-').pop(),10) : 0) + 1).padStart(4, '0')}`;
  }

  function findKP(needle) {
    const all = [...products, ...catalogItems];
    return all.find(x => x.name?.toLowerCase().includes(needle.toLowerCase()));
  }

  const POs = [
    {
      supplier: royal, status: 'received', daysAgo: 12,
      notes: 'KP-LINK · alimento Royal Canin · demo cross-vertical',
      lines: [
        { kpItem: findKP('Royal Canin Adult 3kg'), qty: 12, price: 920 },
        { kpItem: findKP('Pro Plan Cat'), qty: 8, price: 480 },
      ],
    },
    {
      supplier: bayer, status: 'invoiced', daysAgo: 8,
      notes: 'KP-LINK · vacunas + medicamentos Bayer',
      lines: [
        { kpItem: findKP('Vacuna Polivalente'), qty: 30, price: 280 },
        { kpItem: findKP('Amoxicilina 500mg'), qty: 15, price: 145 },
        { kpItem: findKP('Desparasitante Drontal'), qty: 25, price: 180 },
      ],
    },
    {
      supplier: dvnorte, status: 'ordered', daysAgo: 3,
      notes: 'KP-LINK · consumibles farmacia',
      lines: [
        { kpItem: findKP('Jeringas 5ml'), qty: 200, price: 6 },
        { kpItem: findKP('jeringa'), qty: 500, price: 4.5 },
        { kpItem: findKP('Collar antipulgas'), qty: 20, price: 95 },
      ],
    },
    {
      supplier: surtek, status: 'draft', daysAgo: 1,
      notes: 'KP-LINK · DRAFT · borrador insumos esterilización (catalog items)',
      lines: [
        { kpItem: findKP('Gasa estéril'), qty: 50, price: 30 },
        { kpItem: findKP('Suero fisiológico'), qty: 20, price: 65 },
        { kpItem: findKP('Catéter intravenoso'), qty: 30, price: 120 },
      ],
    },
  ];

  let created = 0;
  for (const po of POs) {
    if (!po.supplier) { console.log('  ⚠ Skip · supplier no encontrado'); continue; }
    const existing = await p.purchaseOrder.findFirst({ where: { tenantId: tenant.id, notes: po.notes } });
    if (existing) continue;
    const taxRate = 16;
    let subtotal = 0;
    const validLines = po.lines.filter(l => l.kpItem);
    if (validLines.length === 0) { console.log('  ⚠ Skip · no valid KP items para', po.notes); continue; }
    const linesData = validLines.map((l, idx) => {
      const lineSub = +(l.qty * l.price).toFixed(2);
      subtotal += lineSub;
      const productRef = `kp:${KP_SLUG}:${l.kpItem.id}`;
      const fullReceive = ['received', 'invoiced', 'paid'].includes(po.status);
      return {
        tenantId: tenant.id, lineNumber: idx + 1,
        productRef,
        description: l.kpItem.name + ' (KP-LINK)',
        quantity: l.qty, unit: 'unidad', unitPrice: l.price, subtotal: lineSub,
        receivedQty: fullReceive ? l.qty : 0,
      };
    });
    const tax = +(subtotal * taxRate / 100).toFixed(2);
    const total = +(subtotal + tax).toFixed(2);
    const poNumber = await nextNum();
    const createdAt = new Date(Date.now() - po.daysAgo * 86400000);
    const extra = { requestedDate: createdAt };
    if (['approved','ordered','received','invoiced','paid'].includes(po.status)) extra.approvedAt = new Date(createdAt.getTime() + 8 * 3600000);
    if (['ordered','received','invoiced','paid'].includes(po.status))           extra.orderedAt  = new Date(createdAt.getTime() + 24 * 3600000);
    if (['received','invoiced','paid'].includes(po.status))                     extra.receivedAt = new Date(createdAt.getTime() + 5 * 86400000);
    if (['invoiced','paid'].includes(po.status))                                extra.invoicedAt = new Date(createdAt.getTime() + 6 * 86400000);
    if (po.status === 'paid')                                                   extra.paidAt     = new Date(createdAt.getTime() + 10 * 86400000);

    await p.purchaseOrder.create({
      data: {
        tenantId: tenant.id, poNumber, supplierId: po.supplier.id, status: po.status,
        currency: 'MXN', taxRate, subtotal, tax, total,
        warehouseRef: `inv:${KP_SLUG}:will-resolve`, notes: po.notes,
        expectedDate: new Date(Date.now() + 7 * 86400000),
        createdAt, ...extra,
        lines: { create: linesData },
      },
    });
    created++;
  }
  const total = await p.purchaseOrder.count({ where: { tenantId: tenant.id } });
  console.log('  ✅ POs nuevas con productRef real KP:', created, '· total Pur ahora:', total);
  await p.$disconnect();
})();
