// Imperium · seed Vet-1 cross-vertical para Sales + HR + CRM (N°77 close · datos faltantes)
// Pobla los 3 tenants vacíos del orchestrator con data realista veterinaria
// Idempotente · re-run safe
//
// Usage: node Desktop/_ops/seed-vet-sales-hr-crm.js

const cp = require('child_process');
const fs = require('fs');

const TENANTS = {
  sales: { dir: 'Imperium_Sales',  slug: 'sa-clinica-veterinaria-demo-1-vet-kp',  uuid: '88b90b98' },
  hr:    { dir: 'Imperium_HR',     slug: 'hr-clinica-veterinaria-demo-1-vet-kp',  uuid: 'a3d1c55e' },
  crm:   { dir: 'Imperium_CRM',    slug: 'crm-clinica-veterinaria-demo-1-vet-kp', uuid: 'e6b2e2d3' },
};

function loadPrisma(dir) {
  const ppath = cp.execSync(`find "C:/Users/Administrator/Desktop/${dir}" -name "@prisma" -type d 2>/dev/null | head -1`, { shell: 'C:/Program Files/Git/bin/bash.exe' }).toString().trim();
  return require(ppath + '/client').PrismaClient;
}

async function seedHR() {
  console.log('\n═══ HR · seed clinica veterinaria Vet-1 ═══');
  const HR = loadPrisma(TENANTS.hr.dir);
  const p = new HR();
  const tenant = await p.tenant.findFirst({ where: { slug: TENANTS.hr.slug } });
  if (!tenant) { console.log('  ❌ tenant HR no existe · skip'); await p.$disconnect(); return; }

  // Departamentos
  const depts = [
    { name: 'Atención Médica', code: 'VET' },
    { name: 'Recepción',       code: 'REC' },
    { name: 'Administración',  code: 'ADM' },
  ];
  const deptMap = {};
  for (const d of depts) {
    let dept = await p.department.findFirst({ where: { tenantId: tenant.id, name: d.name } });
    if (!dept) dept = await p.department.create({ data: { tenantId: tenant.id, ...d } });
    deptMap[d.code] = dept;
  }
  console.log('  · Departamentos:', Object.keys(deptMap).join(' · '));

  // Puestos
  const positions = [
    { title: 'Médico Veterinario Zootecnista', level: 'senior',  deptCode: 'VET', baseSalaryMxn: 28000 },
    { title: 'MVZ Asistente',                  level: 'mid',     deptCode: 'VET', baseSalaryMxn: 18000 },
    { title: 'Recepcionista',                  level: 'junior',  deptCode: 'REC', baseSalaryMxn: 10000 },
    { title: 'Gerente de Sucursal',            level: 'manager', deptCode: 'ADM', baseSalaryMxn: 22000 },
  ];
  const posMap = {};
  for (const ps of positions) {
    let pos = await p.position.findFirst({ where: { tenantId: tenant.id, title: ps.title } });
    if (!pos) pos = await p.position.create({ data: { tenantId: tenant.id, title: ps.title, level: ps.level, baseSalaryMxn: ps.baseSalaryMxn, departmentId: deptMap[ps.deptCode].id } });
    posMap[ps.title] = pos;
  }
  console.log('  · Puestos:', Object.keys(posMap).length);

  // Empleados realistas
  const employees = [
    { fullName: 'Dra. María Fernández López',  email: 'mvz.maria@vet1.demo',     phone: '55 1234 5678', position: 'Médico Veterinario Zootecnista', dept: 'VET', hireYearsAgo: 4,   externalRef: 'kp:demo1-vet:vet-001' },
    { fullName: 'Dr. Carlos Mendoza Ruiz',     email: 'mvz.carlos@vet1.demo',    phone: '55 2345 6789', position: 'Médico Veterinario Zootecnista', dept: 'VET', hireYearsAgo: 2,   externalRef: 'kp:demo1-vet:vet-002' },
    { fullName: 'Lic. Sofía García Martínez',  email: 'asistente.sofia@vet1.demo', phone: '55 3456 7890', position: 'MVZ Asistente',                 dept: 'VET', hireYearsAgo: 1,   externalRef: 'kp:demo1-vet:vet-003' },
    { fullName: 'Ana Patricia Jiménez',        email: 'recepcion.ana@vet1.demo', phone: '55 4567 8901', position: 'Recepcionista',                   dept: 'REC', hireYearsAgo: 3,   externalRef: 'kp:demo1-vet:rec-001' },
    { fullName: 'Roberto Sánchez Torres',      email: 'recepcion.roberto@vet1.demo', phone: '55 5678 9012', position: 'Recepcionista',                dept: 'REC', hireYearsAgo: 0.5, externalRef: 'kp:demo1-vet:rec-002' },
    { fullName: 'C.P. Lucía Ramírez Castro',   email: 'gerente.lucia@vet1.demo', phone: '55 6789 0123', position: 'Gerente de Sucursal',             dept: 'ADM', hireYearsAgo: 5,   externalRef: 'kp:demo1-vet:adm-001' },
  ];
  let empCreated = 0;
  for (const e of employees) {
    const existing = await p.employee.findFirst({ where: { tenantId: tenant.id, externalRef: e.externalRef } });
    if (existing) continue;
    await p.employee.create({
      data: {
        tenantId: tenant.id, fullName: e.fullName, email: e.email, phone: e.phone,
        positionId: posMap[e.position].id, departmentId: deptMap[e.dept].id,
        hireDate: new Date(Date.now() - e.hireYearsAgo * 365 * 86400000),
        status: 'active', externalRef: e.externalRef,
        rfc: 'XAXX010101000', // placeholder
      },
    });
    empCreated++;
  }
  console.log('  ✅ Empleados creados:', empCreated, '· total ahora:', await p.employee.count({ where: { tenantId: tenant.id } }));
  await p.$disconnect();
}

async function seedCRM() {
  console.log('\n═══ CRM · seed clientes (dueños de mascotas) Vet-1 ═══');
  const CRM = loadPrisma(TENANTS.crm.dir);
  const p = new CRM();
  const tenant = await p.tenant.findFirst({ where: { slug: TENANTS.crm.slug } });
  if (!tenant) { console.log('  ❌ tenant CRM no existe · skip'); await p.$disconnect(); return; }

  // Pipeline default (necesario si futuro agregamos opportunities)
  const pipeline = await p.pipeline.findFirst({ where: { tenantId: tenant.id, isDefault: true } });
  if (!pipeline) {
    await p.pipeline.create({
      data: { tenantId: tenant.id, name: 'Pipeline Veterinaria', isDefault: true,
        stages: JSON.stringify([
          { code: 'prospecto',    name: 'Prospecto',         probability: 10 },
          { code: 'primera-cita', name: 'Primera cita',      probability: 30 },
          { code: 'paciente',     name: 'Paciente activo',   probability: 70 },
          { code: 'frecuente',    name: 'Cliente frecuente', probability: 95 },
        ]) } });
    console.log('  · Pipeline Veterinaria creado');
  }

  // Customers (dueños de mascotas · sync from KP demo1-vet owners)
  const customers = [
    { firstName: 'Valeria',  lastName: 'Rojas Hernández',   email: 'valeria.rojas@email.com',   phone: '55 1010 2020', externalRef: 'kp:demo1-vet:owner-001', source: 'kp:owner', tags: '["frecuente","golden-retriever"]' },
    { firstName: 'Roberto',  lastName: 'Méndez Pérez',      email: 'r.mendez@email.com',        phone: '55 2020 3030', externalRef: 'kp:demo1-vet:owner-002', source: 'kp:owner', tags: '["prospecto","border-collie"]' },
    { firstName: 'Adriana',  lastName: 'González Vázquez',  email: 'a.gonzalez@correo.mx',      phone: '55 3030 4040', externalRef: 'kp:demo1-vet:owner-003', source: 'kp:owner', tags: '["paciente","persa"]' },
    { firstName: 'Luis',     lastName: 'Torres Aguilar',    email: 'luis.torres@email.com',     phone: '55 4040 5050', externalRef: 'kp:demo1-vet:owner-004', source: 'kp:owner', tags: '["paciente","labrador"]' },
    { firstName: 'Mariana',  lastName: 'Castillo Ríos',     email: 'mariana.castillo@email.com', phone: '55 5050 6060', externalRef: 'kp:demo1-vet:owner-005', source: 'kp:owner', tags: '["frecuente","chihuahua","poodle"]' },
    { firstName: 'Diego',    lastName: 'Hernández Cruz',    email: 'diego.hc@email.com',         phone: '55 6060 7070', externalRef: 'kp:demo1-vet:owner-006', source: 'kp:owner', tags: '["primera-cita","gato-comun"]' },
    { firstName: 'Patricia', lastName: 'Vargas López',      email: 'pvargas@correo.mx',          phone: '55 7070 8080', externalRef: 'kp:demo1-vet:owner-007', source: 'kp:owner', tags: '["frecuente","schnauzer"]' },
    { firstName: 'Andrés',   lastName: 'Ramírez Soto',      email: 'andres.r@email.com',         phone: '55 8080 9090', externalRef: 'kp:demo1-vet:owner-008', source: 'kp:owner', tags: '["prospecto","husky"]' },
  ];
  let crCreated = 0;
  for (const c of customers) {
    const existing = await p.customer.findFirst({ where: { tenantId: tenant.id, externalRef: c.externalRef } });
    if (existing) continue;
    await p.customer.create({ data: { tenantId: tenant.id, type: 'person', ...c, active: true } });
    crCreated++;
  }
  console.log('  ✅ Customers creados:', crCreated, '· total ahora:', await p.customer.count({ where: { tenantId: tenant.id } }));
  await p.$disconnect();
}

async function seedSales() {
  console.log('\n═══ Sales · seed cotizaciones Vet-1 ═══');
  const SA = loadPrisma(TENANTS.sales.dir);
  const p = new SA();
  const tenant = await p.tenant.findFirst({ where: { slug: TENANTS.sales.slug } });
  if (!tenant) { console.log('  ❌ tenant Sales no existe · skip'); await p.$disconnect(); return; }

  const year = new Date().getFullYear();
  async function nextNum() {
    const last = await p.quote.findFirst({ where: { tenantId: tenant.id, number: { startsWith: `QT-${year}-` } }, orderBy: { number: 'desc' } });
    return `QT-${year}-${String((last ? parseInt(last.number.split('-').pop(),10) : 0) + 1).padStart(4, '0')}`;
  }

  const quotes = [
    {
      customer: 'Valeria Rojas Hernández', email: 'valeria.rojas@email.com', phone: '55 1010 2020',
      status: 'accepted', daysAgo: 30,
      notes: 'Paquete preventivo anual · Golden Retriever',
      lines: [
        { description: 'Consulta general',                  qty: 1, price: 450 },
        { description: 'Vacuna antirrábica',                qty: 1, price: 280 },
        { description: 'Vacuna quíntuple',                  qty: 1, price: 380 },
        { description: 'Antiparasitario Bravecto · 3 meses', qty: 1, price: 580 },
        { description: 'Limpieza dental',                    qty: 1, price: 1850 },
      ],
    },
    {
      customer: 'Roberto Méndez Pérez', email: 'r.mendez@email.com', phone: '55 2020 3030',
      status: 'sent', daysAgo: 8,
      notes: 'Cotización primera cita Border Collie',
      lines: [
        { description: 'Consulta inicial',                  qty: 1, price: 450 },
        { description: 'Hemograma + química',               qty: 1, price: 920 },
        { description: 'Esquema vacunal cachorro · 3 dosis', qty: 1, price: 1450 },
      ],
    },
    {
      customer: 'Mariana Castillo Ríos', email: 'mariana.castillo@email.com', phone: '55 5050 6060',
      status: 'draft', daysAgo: 2,
      notes: 'Cirugía esterilización Chihuahua · pendiente cita',
      lines: [
        { description: 'Esterilización (OVH)',              qty: 1, price: 3500 },
        { description: 'Anestesia + monitoreo',             qty: 1, price: 850 },
        { description: 'Antibiótico post-quirúrgico',       qty: 1, price: 320 },
        { description: 'Consulta seguimiento (incluida)',   qty: 1, price: 0 },
      ],
    },
    {
      customer: 'Patricia Vargas López', email: 'pvargas@correo.mx', phone: '55 7070 8080',
      status: 'accepted', daysAgo: 14,
      notes: 'Plan nutrición Schnauzer · senior',
      lines: [
        { description: 'Royal Canin Renal · 2kg (3 sacos)', qty: 3, price: 920 },
        { description: 'Consulta nutrición',                qty: 1, price: 550 },
        { description: 'Análisis bioquímico renal',         qty: 1, price: 1180 },
      ],
    },
    {
      customer: 'Andrés Ramírez Soto', email: 'andres.r@email.com', phone: '55 8080 9090',
      status: 'rejected', daysAgo: 21,
      notes: 'Cotización para baño + estética · cliente decidió otro lugar',
      lines: [
        { description: 'Baño + corte raza grande',          qty: 1, price: 650 },
        { description: 'Limpieza de oídos',                 qty: 1, price: 180 },
        { description: 'Corte de uñas',                     qty: 1, price: 120 },
      ],
    },
    {
      customer: 'Diego Hernández Cruz', email: 'diego.hc@email.com', phone: '55 6060 7070',
      status: 'sent', daysAgo: 4,
      notes: 'Primera cita gato común · paquete básico',
      lines: [
        { description: 'Consulta felina inicial',           qty: 1, price: 480 },
        { description: 'Vacuna triple felina',              qty: 1, price: 380 },
        { description: 'Desparasitación interna',           qty: 1, price: 250 },
      ],
    },
  ];

  let qCreated = 0;
  for (const q of quotes) {
    const existing = await p.quote.findFirst({ where: { tenantId: tenant.id, customerName: q.customer, notes: q.notes } });
    if (existing) continue;
    const num = await nextNum();
    const taxRate = 16;
    let subtotal = 0;
    const items = q.lines.map((l, i) => {
      const lineSub = +(l.qty * l.price).toFixed(2);
      subtotal += lineSub;
      return { description: l.description, quantity: l.qty, unitPrice: l.price, subtotal: lineSub, position: i };
    });
    const tax = +(subtotal * taxRate / 100).toFixed(2);
    const total = +(subtotal + tax).toFixed(2);
    const createdAt = new Date(Date.now() - q.daysAgo * 86400000);
    const extra = {};
    if (q.status === 'sent' || q.status === 'accepted' || q.status === 'rejected') extra.sentAt = createdAt;
    if (q.status === 'accepted') extra.acceptedAt = new Date(createdAt.getTime() + 2 * 86400000);
    if (q.status === 'rejected') extra.rejectedAt = new Date(createdAt.getTime() + 5 * 86400000);

    await p.quote.create({
      data: {
        tenantId: tenant.id, number: num,
        customerName: q.customer, customerEmail: q.email, customerPhone: q.phone,
        status: q.status, currency: 'MXN', taxRate, subtotal, tax, total,
        validUntil: new Date(Date.now() + 15 * 86400000),
        sourceVerticals: JSON.stringify([{ moduleCode: 'kp', itemCount: items.length, subtotalMXN: subtotal }]),
        notes: q.notes, createdAt, ...extra,
        items: { create: items },
      },
    });
    qCreated++;
  }
  console.log('  ✅ Quotes creadas:', qCreated, '· total ahora:', await p.quote.count({ where: { tenantId: tenant.id } }));
  await p.$disconnect();
}

(async () => {
  console.log('\n═══════════════════════════════════════════════════════════════════');
  console.log('  Imperium · seed Vet-1 cross-vertical · Sales + HR + CRM (N°77close)');
  console.log('═══════════════════════════════════════════════════════════════════');
  try {
    await seedHR();
    await seedCRM();
    await seedSales();
    console.log('\n  ✅ Seed completo · gráficas de Sales/HR/CRM ahora con data');
    console.log('  Login: demo1@local.com / Demo12345! → http://localhost:5180 (Hub)\n');
  } catch (e) {
    console.error('❌ Seed falló:', e.message, e.stack);
    process.exit(1);
  }
})();
