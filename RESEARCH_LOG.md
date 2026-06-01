# Research Log · Imperium

> **Uso interno · NO commitear a repos verticales (KP, NK/Almena, Sales, RT, Hub, Admin, Finance, HR, CRM).**
> Bitácora privada de repos/fuentes consultadas durante el desarrollo.
> NO es atribución legal · es memoria personal para volver a encontrar referencias en futuros proyectos.
> Si copiaste código con licencia (MIT/Apache/etc) · mantener license header en el archivo destino (eso sí es obligación legal).

## Cómo usar

- **Agregar** cuando consultes un repo/tutorial/artículo durante una feature
- **Granularidad**: por feature/concepto del proyecto, NO por tool global (eso vive en `EXTERNAL_TOOLS.md`)
- **Buscar después**: grep por palabra clave del concepto → encontrás repo URL y dónde lo aplicaste
- **Reusabilidad**: si en otro proyecto futuro necesitás "ese patrón de X que ya usé", está acá
- **Si no recordás URL exacta** · escribir lo que sí recordás (nombre aproximado · keywords · fecha aproximada) · mejor a perder la pista total

---

## Por feature / concepto

### Knowledge graph del codebase (Forge audit · KP · RT)
- **Tool**: graphify (CLI Python)
- **Repo**: https://github.com/safishamsi/graphify
- **Sitio**: https://graphify.net · **PyPI**: https://pypi.org/project/graphifyy
- **Cuándo lo encontré**: 2026-05-13 N°28
- **Por qué sirvió**: análisis estructural · 0 tokens · 5-7s en codebases medianos · BFS query "where is X" sin grep manual
- **Reusable en**: cualquier futuro proyecto · cross-IDE (16+ asistentes) · independiente del stack
- **Notas**: outputs en `<repo>/graphify-out/` · gitignore recomendado

### TDD validation pattern (Sales · validateRfc)
- **Repo origen**: https://github.com/obra/superpowers (plugin Anthropic marketplace)
- **Cuándo lo encontré**: 2026-05-14 N°30
- **Qué tomé**: methodology de TDD enforce (write test first · run · implement · refactor) · función `validateRfc` portada a `Imperium_Sales/utils/`
- **Por qué sirvió**: 13 tests TDD · 0 conflictos con skills propios · workflow disciplinado en feature ambigua
- **Reusable en**: cualquier feature con lógica de validación que necesite tests sólidos
- **Notas**: uso QUIRÚRGICO · brainstorming sobre-pregunta · solo en features ambiguas reales

### Security baseline rules (NK/Almena)
- **Repo origen**: TikiTribe/claude-secure-coding-rules v1.0.0 (MIT)
- **Cuándo lo encontré**: pre-N°15 · adopción documentada en NK `feedback_security_rules_overrides`
- **Qué tomé**: OWASP 2025 · javascript · express · react reglas · re-sincronizables via `Desktop/sync-security-rules.sh`
- **Source canónico local**: `Desktop/_security-rules-source/`
- **Por qué sirvió**: baseline cubre A01-A10 sin escribir cada regla a mano
- **Reusable en**: cualquier vertical futuro · script de sync ya hecho
- **Notas**: overrides documentados en `<vertical>/.claude/security-rules/OVERRIDES.md`

### Build-gate methodology (verify-fix-loop · Imperium_*)
- **Origen**: WigFlow Recipe BUILD.md pattern (proyecto interno previo)
- **Cuándo lo encontré**: 2026-05-04
- **Qué tomé**: pattern build → test → lint loop hasta passing · materializado como skill `verify-fix-loop` propia
- **Por qué sirvió**: zero-regression antes de declarar feature done · cubre el gap de OMC team mode sin sus problemas (tmux dep)
- **Reusable en**: cualquier vertical Imperium · ya es skill global
- **Notas**: complementario a `simplify` (calidad post-cambio)

### Result<T,E> error type (imperium-core v0.3)
- **Origen conceptual**: WigFlow + Rust/TypeScript común
- **Cuándo lo encontré**: 2026-05-04
- **Qué tomé**: pattern de retorno explícito (no exceptions silenciosas) en imperium-core
- **Por qué sirvió**: errores type-safe · imposible olvidar manejarlos
- **Reusable en**: cualquier librería propia Imperium
- **Notas**: pattern conceptual · no copia de código · sin obligación legal

### Mapa interactivo (Forge interactive-map)
- **Lib usada**: leaflet via npm
- **Repo lib**: https://github.com/Leaflet/Leaflet
- **Cuándo**: pre-N°4 · adoptado early en NK
- **Qué tomé**: lib completa como dep · wrapper propio (renderMarker render prop pattern propio)
- **Reusable en**: KP + NK ya consumen · cualquier vertical con geolocalización
- **Notas**: license BSD-2-Clause (en node_modules) · sin obligación extra

### PDF export config-driven (Forge pdf-export)
- **Libs usadas**: jsPDF + jspdf-autotable via npm (lazy load)
- **Repo libs**: https://github.com/parallax/jsPDF · https://github.com/simonbengtsson/jsPDF-AutoTable
- **Cuándo**: integrado RT N°22 aprox
- **Qué tomé**: libs como deps · placeholders `{{campo}}` pattern propio
- **Reusable en**: RT (Panorama/Empresas) ya consume · agnóstico vertical
- **Notas**: licencias MIT (en node_modules)

### CSV export config-driven (Forge csv-export)
- **Origen**: extraído de legacy Kompaws (refactor propio · sin lib externa)
- **Cuándo**: integrado RT 4 tablas
- **Qué tomé**: lógica propia · UTF-8 BOM Excel-friendly
- **Reusable en**: cualquier vertical Imperium
- **Notas**: sin dep externa · 100% propio · sin obligación

### Double-entry accounting (Finance G.1 · medici-style)
- **Inspiración conceptual**: medici (https://github.com/koresar/medici · npm `medici`)
- **Cuándo**: 2026-05-04 N°17
- **Qué tomé**: nombre del estilo solamente · implementación 100% propia · 23 cuentas NIF · sin código copiado
- **Por qué sirvió**: vocabulario estándar para describir lo que construí (debit/credit, journal entries)
- **Reusable en**: si futuro proyecto necesita contabilidad básica · revisar medici lib antes de reimplementar
- **Notas**: no copia · solo referencia conceptual

### HMAC-SHA256 keygen offline (NK Modo B · Forge keygen-hmac v1)
- **Origen**: implementación propia · pattern crypto standard
- **Cuándo**: pre-N°4 · extraído a Forge 2026-05-04
- **Qué tomé**: nada externo · `crypto` built-in Node
- **Reusable en**: cualquier feature que necesite firma offline (Paladin tier Almena · futuro)
- **Notas**: agnóstico al payload format · binary-compat v3.0 NK

---

## Agendado (consultar cuando llegue el momento)

### Knowledge graph alternativo (si Graphify se queda corto)
- **Repo**: https://github.com/Lum1104/Understand-Anything · 20.2k ⭐ · MIT
- **Cuándo encontrado**: 2026-05-22 (batch 5 repos)
- **Por qué bookmark**: tiene **diff impact analysis** (qué se rompe si tocás X) · feature que Graphify NO tiene · útil para refactors multi-archivo
- **NO migrar**: Graphify ya validado · 0 tokens · UA requiere LLM calls (multi-agent pipeline · costo Claude API)
- **Cuándo probar**: si en sesión grande necesitás predecir blast-radius y Graphify no alcanza · sandbox aislado
- **Install si se decide**: `/plugin marketplace add` + `/plugin install understand-anything` (Claude Code) o bash installer cross-IDE
- **Stack**: TS+Python · pnpm workspaces

### Free-tier LLM API proxy (solo sandbox · NO prod · NO cliente)
- **Repo**: https://github.com/tashfeenahmed/freellmapi · 4.3k ⭐ · MIT
- **Cuándo encontrado**: 2026-05-22 (batch 5 repos)
- **⚠ Flag riesgo**: el propio README dice "for personal experimentation only" · agregar free-tier keys puede violar TOS de providers (Gemini · Groq · etc · "1 key per person")
- **NO para**: producción · cliente · prod Imperium AI layer
- **Caso de uso limitado**: experimentar con features que requieran LLM en dev sandbox sin pagar · pero free tier directo de Gemini ya alcanza para la mayoría
- **Cuándo consultar**: si necesitás failover entre providers en experimento personal · evaluar si vale el riesgo TOS

### Generador de presentaciones self-hosted (white-label / migration Gamma)
- **Repo**: https://github.com/presenton/presenton · 6.1k ⭐ · Apache 2.0
- **Sitio**: https://presenton.ai
- **Cuándo encontrado**: 2026-05-22 (batch 5 repos)
- **Por qué bookmark estratégico**:
  - **White-label futuro**: Imperium Enterprise tier puede ofrecer "generación de reportes ejecutivos PPTX" sin lockin de Gamma
  - **Migration path Gamma**: si Gamma sube precios o discontinúa MCP, tenés alternativa lista
  - **Stack afín**: TS+FastAPI+Docker · BYOK (Bring Your Own Key) · templates HTML+Tailwind brandeables
  - Output: PPTX editable + PDF
- **Cuándo activar**: fase 2027-H2 (Imperium Workflow) · o antes si Gamma falla · o cuando cliente Enterprise pida reportes branded sin lockin
- **Install si se decide**: Docker one-command o Electron (Node + Python 3.11 + uv)

### AI-first security scanner (✅ evaluado 2026-05-22 · retenido para due diligence externa)
- **Repo**: https://github.com/Pantheon-Security/medusa · 568 ⭐ · AGPL-3.0
- **Status**: 🟢 INSTALADO en venv aislado · **NO para verticales Imperium** · SÍ para due diligence pre-adopción OSS
- **Hallazgo eval**: medusa es orquestador (delega a ESLint/gitleaks/etc) · sin esos linters · solo corren scanners Python-AI · 100% FPs contra CLAUDE.md legítimo
- **Use case sobreviviente**: `medusa scan -g user/repo` para escanear repos externos antes de adoptarlos
- **Ver detalles completos**: `EXTERNAL_TOOLS.md` § medusa · install + rollback + cuándo correr + comparación con alternativas
- **Workflow**: cuando user pase nuevo repo a evaluar · correr `medusa scan -g <repo>` como paso de due diligence antes del veredicto

### OCR + LLM extraction de facturas (Finance G.1+ OCR feature)
- **Repo a leer**: https://github.com/vas3k/TaxHacker
- **Cuándo consultar**: cuando se diseñe feature OCR de Finance · NO antes
- **Para qué**: leer `prisma/schema.prisma` + ruta OCR · stack idéntico (Next.js 15 + Prisma + PostgreSQL)
- **NO adoptar como dep**: gap CFDI 4.0 + "early dev"
- **Proceso**: clonar temporal → leer → documentar hallazgos en `00-DOCS-MAESTRAS/` → borrar clone

### RAG con knowledge graph (si Vet-1 piloto pide Q&A clínico)
- **Repo a evaluar**: https://github.com/HKUDS/LightRAG
- **Cuándo consultar**: post-discovery cliente vet · si pide búsqueda semántica
- **Para qué**: Q&A en lenguaje natural sobre expedientes clínicos
- **Stack pesado**: Python + LLM 32B+ + 32K context + Chroma/Neo4j/Postgres vector

### Specialized agents (cherry-pick post-piloto)
- **Repos**: 
  - https://github.com/msitarzewski/agency-agents (144 .md)
  - https://github.com/affaan-m/everything-claude-code (60+ agents · 228+ skills · AgentShield)
  - https://github.com/sickn33/antigravity-awesome-skills (1,459+ skills cross-IDE)
- **Cuándo**: post-piloto Vet-1 · NO bulk install
- **Para qué**: cherry-pick 3-5 .md específicos (CFDI/fiscal-mx · sales-engineer · qa-strategist)
- **Cherry-pick AgentShield específicamente**: 1,282 tests · 102 rules · evaluar como reemplazo TikiTribe

### Landing público marketing-site (si se decide Next.js)
- **Repo referencia**: https://github.com/Hainrixz/claude-webkit (genera landings Next.js 15 + Tailwind 4 + shadcn + Framer)
- **Cuándo**: post-rebranding · post-IMPI · si se hace marketing-site separado del producto
- **NO migrar verticales**: usamos Vite + React · stack distinto

### Onboarding / profundizar Claude Code (cualquier momento)
- **Repo bookmark**: https://github.com/FlorianBruniaux/claude-code-ultimate-guide (CC-BY-SA-4.0 · EN + FR)
- **Para qué**: 24K líneas guía · 181 templates · 28 CVEs trackeados · útil onboarding nuevo dev al equipo

### Eval batch repos externos · N°80 (2026-05-28 · skills tooling · cyber · multimodal)
- **Contexto**: Alejandro pasó 7 repos para "revisar y anexar lo útil". Análisis de relevancia para Imperium ERP / Almena IT-sec / Kompaws / workflow de skills.
- **🟢 Candidatos a anexar**:
  - https://github.com/microsoft/SkillOpt (MIT · 1.8k★) — optimizador de skills NL (trajectory edits + validation gates → best_skill.md). Adoptar la *metodología* (validation-gated skill edit), no el framework Python pesado. Aplica a verify-fix-loop / github-research / graphify.
  - https://github.com/earlyaidopters/claudeclaw (sin LICENSE · 150★ · TS) — Claude Code CLI como bot Telegram (ops remotas desde móvil). ⚠ ejecuta `claude` real + bot token = riesgo shell-equiv. medusa scan N°80 → `_ops/medusa-claudeclaw-2026-05-28.log`. NO en SERVER288 · despliegue aislado no-prod si se adopta.
- **🟡 Referencia (no copiar código · LICENSE varía)**:
  - https://github.com/NVIDIA/skills (Apache+CC-BY · 619★) — contenido GPU/CUDA no aplica · la spec agent-skills + CLI `npx skills` (agentskills.io / vercel-labs/skills) vale conocer.
  - https://github.com/CarterPerez-dev/Cybersecurity-Projects (sin LICENSE · 2.4k★) — 70 proyectos cyber + roadmaps · ideas de features para Almena · NO copiar (copyright reservado).
- **🔵 Observar (off-domain · futuro)**:
  - https://github.com/HKUDS/ViMax (MIT · 8k★) — generación de video agéntica · futuro: auto demo-reels marketing.
  - https://github.com/ysharma3501/LuxTTS (sin LICENSE · 4k★) — TTS voice-cloning ligero (1GB VRAM · 150x realtime) · futuro: recordatorios por voz Kompaws.
- **🔴 NO anexar**:
  - https://github.com/ytisf/theZoo (13k★) — malware VIVO · no es librería. Único uso legítimo = validar detección Almena en VM aislada sin red (investigación defensiva) · NUNCA integrar a producto ni clonar en SERVER288.
- **Licencias**: la mayoría `license: none` en gh = copyright reservado · NO copiar código sin LICENSE permisivo. SkillOpt/ViMax MIT · NVIDIA Apache/CC-BY.

---

## Reglas de mantenimiento

1. **Agregar cuando**: consultás un repo/tutorial/artículo que aporta a una feature concreta
2. **NO atribuir en código** por default · solo si copiaste literal código con licencia que lo requiera
3. **Si no recordás URL exacta**: escribir todo lo que sí recordás (keywords · fecha aproximada) · cualquier rastro > pista perdida
4. **Revisar cada cierre de sesión grande**: si surgió fuente nueva no capturada · agregar
5. **Si un repo se vuelve dep operacional** (instalado · activo) · mover a `EXTERNAL_TOOLS.md` y dejar puntero acá
