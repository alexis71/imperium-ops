# Imperium · External Tools Tracker

> Tools externos evaluados / instalados / agendados para el workflow Imperium.
> Single source of truth para "qué herramientas externas usamos y por qué".
> Actualizado: 2026-05-13 · sesión N°29 (Graphify validado en Forge · pasó a ✅)

---

## ✅ Instaladas / activas

| Tool | Versión | Path | Propósito | Notas |
|---|---|---|---|---|
| **Claude Code** | 2.1.140 | `npm global` | Asistente principal | latest channel · stable channel está en 2.1.128 |
| **Python** | 3.12.7 | `%LOCALAPPDATA%\Programs\Python\Python312\` | Runtime para Graphify (user-scope · no admin) | installer en `_ops/installers/python-3.12.7-amd64.exe` · PrependPath=1 user PATH |
| **pipx** | 1.12.0 | `%APPDATA%\Roaming\Python\Python312\Scripts\pipx.exe` | Aislar CLIs Python en venvs | Path: `%APPDATA%\Roaming\Python\Python312\Scripts` (NO en PATH global por default) |
| **Graphify (graphifyy)** | 0.7.16 + [mcp] | `C:\Users\Administrator\.local\bin\graphify.exe` | Code knowledge graph · BFS query · communities · god nodes | Repo: https://github.com/safishamsi/graphify · sitio: https://graphify.net · PyPI: https://pypi.org/project/graphifyy · validado en Forge N°29 · ver § Graphify abajo |
| **CodeFlow** | git HEAD (clonado 2026-05-13) | `Desktop/_ops/codeflow/` | Visualizador one-shot de arquitectura · screenshots para decks | Single HTML · zero deps · doble-click `index.html` |
| **Superpowers (obra)** | 5.1.0 plugin | `~/.claude/plugins/cache/claude-plugins-official/superpowers/` | Methodology completa (brainstorming · TDD enforce · git worktrees · spec/plan/exec) · 14 skills `superpowers:*` | Plugin oficial Anthropic marketplace · ADOPTED N°29 con USO QUIRÚRGICO (no default) · ver memoria `project_superpowers_adopted_2026-05-14` para guidelines cuándo SÍ vs cuándo NO invocar (brainstorming sobre-pregunta · vale solo en features ambiguas reales) |
| **UI/UX Pro Max (uipro-cli)** | npm latest | `Desktop/_sandbox-uipro/.claude/skills/ui-ux-pro-max/` (LOCAL · NO global) | 67 styles · 96 paletas · 57 font pairings · 99 UX guidelines · 25 charts · 13 stacks | npm install -g uipro-cli + `uipro init --ai claude` per-project (instala LOCAL en `<cwd>/.claude/skills/`) · 712 KB · 31 archivos · 0 conflictos con globales · evaluado N°30 ✅ tooling sano · NO copiado aún a verticales productivos · evaluar adopción real cuando QA visual sweep o rebranding · uninstall: `npm uninstall -g uipro-cli` + remove sandbox dir |
| **Verify-fix-loop skill** | (built-in skill) | `.claude/skills/` | build → test → lint loop hasta passing | Cubre rol de OMC team mode |
| **github-research skill** | (built-in skill) | `.claude/skills/` | Buscar 3-5 OSS refs antes de implementar módulo nuevo | Adoptado del workflow WigFlow |
| **simplify skill** | (built-in skill) | `.claude/skills/` | Code review post-cambio · busca reuse | Calidad post-feature work |
| **medusa (medusa-security)** | 2026.5.9 | `Desktop/_ops/medusa-env/Scripts/medusa.exe` (venv aislado) | **Due diligence pre-adopción de OSS externos** · NO scanner de verticales Imperium | Repo: https://github.com/Pantheon-Security/medusa · AGPL-3.0 (OK para CLI privado · no SaaS · no redistribución) · evaluado 2026-05-22 contra NK · ver § medusa abajo |
| **chart.js + react-chartjs-2** | 4.5.1 + 5.3.1 | dep de `<vertical>/client` (bundle SaaS) | Gráficas premium en dashboards · reemplaza SVG hechos a mano | **Ambos MIT ✅ vendibles** · SE SIRVEN al cliente (no dev-tool) · consumidos vía wrapper Forge `@nomadknight/charts` (ver § charts) · adoptados N°85 spike Kompaws |

---

## 🟢 Graphify · resultado validación N°29 (2026-05-13)

**Test target:** `Desktop/Imperium_Forge/` (121 archivos · ~73K palabras · ~0.66 MB sin node_modules)

**Comando:** `graphify update Desktop\Imperium_Forge` (AST-only · sin LLM · sin API key)

**Métricas reales (Forge · validación N°29):**
- Tiempo total: **5.6s** (8 workers AST paralelos)
- Output: **920 nodos · 871 edges · 115 communities** (98 mostradas · 17 thin omitidas)
- Extracción: 99% EXTRACTED · 1% INFERRED (6 edges con avg confidence 0.8)
- Token cost: **0 input · 0 output** (sin LLM en modo `update`)
- Output size: ~1.2 MB (graph.html 626 KB + graph.json 590 KB + GRAPH_REPORT.md 22 KB + 121 cache ASTs)

**Métricas comparativas N°30 (3 codebases · /graphify install --platform claude ✅):**

| Repo | Files | Nodes | Edges | Communities | Time |
|---|---|---|---|---|---|
| Imperium_Forge | 121 | 920 | 871 | 115 | 5.6s |
| Kompaws | 143 | 908 | 1202 | 74 | 7s |
| RoundTable_v1 | 110 | 753 | 930 | 46 | 5s |

Observaciones:
- Escala bien · 0 tokens · 5-7s incluso en codebases medianos productivos
- KP tiene **más edges/file** (1202/143 = 8.4) · indica codebase muy interconectado (multi-modelo Patient/Owner/Branch/CatalogItem/Product/Charge/etc · domain rico)
- RT tiene **menos communities/file** (46/110 = 0.42) · estructura más jerárquica · típico de proyectos centrados en una entidad principal (Project)
- MCP skill `/graphify` registrado en `~/.claude/skills/graphify/SKILL.md` (install N°30)
- CLAUDE.md global creado en `~/.claude/CLAUDE.md` (4 líneas · solo trigger doc · NO compite con auto-memory)

**Outputs útiles inmediatos (en `<repo>/graphify-out/`):**
- `graph.html` · viz interactiva D3 · doble-click para navegar
- `graph.json` · grafo serializado · alimenta queries
- `GRAPH_REPORT.md` · god nodes (top 10 hubs) + surprising connections (INFERRED edges) + 98 community hubs en formato wiki `[[link]]` (Obsidian-compatible)

**God nodes detectados en Forge (top 5 · sanity check):**
1. `Convenciones · Verticales → Imperium Analytics` — 16 edges
2. `Imperium Analytics Admin — Design Document` — 14 edges
3. `5. API endpoints completos` — 12 edges
4. `Imperium Analytics Admin · Flujos Visuales` — 12 edges
5. `Imperium ERP · Resumen del deck` — 11 edges

**Surprising connections detectadas (INFERRED · cross-package):**
- `Login()` → `useAuth()` · `landing-templates` → `auth-core`
- `Settings()` → `useAuth()` · `auth-core/client` → `auth-core/client`
- `Layout()` → `useAuth()` · `ui-kit` → `auth-core`

**Query BFS funciona (sin LLM):** `graphify query "How are extensions registered and exposed?"` → 40 nodos relevantes con `src=path loc=Lxx community=N` cada uno · útil para "dónde está X" sin grep manual.

**⚠ Gotcha Windows · encoding:** PowerShell default cp1252 no soporta emojis Unicode (graphify usa 🆕🧭🎨🔮 en outputs). Setear antes de cualquier llamada:
```powershell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$env:PYTHONIOENCODING = 'utf-8'
```

**Cómo retomar / siguiente paso:**
- Expandir a Kompaws (`Desktop/Kompaws`) y RT (`Desktop/RoundTable_v1`) — codebases más grandes (~2K-5K nodos esperados)
- Decidir si instalar el skill MCP en Claude Code: `graphify install --platform claude` (registra `/graphify` en `.claude/skills/`)
- Agregar `graphify-out/` y `graphify-out/cache/` a `.gitignore` de cada repo donde se corra
- Considerar `graphify watch <path>` durante sesión activa (rebuild automático on file change)
- Para extracción semántica con LLM: setear `GEMINI_API_KEY` o `GOOGLE_API_KEY` y correr `graphify extract` (el modo gratuito ya rinde · LLM mejora resúmenes pero $$)

**Portabilidad cross-IDE (confirmado 2026-05-14 vía repo safishamsi/graphify):**

Graphify es agnóstico al asistente · soporta **16+ AI coding assistants** · `graphify install --platform <X>` instala el skill correspondiente:

```
claude · codex · opencode · cursor · gemini · copilot-cli · vscode-copilot ·
aider · claw · droid · trae · trae-cn · hermes · kimi · kiro · pi · antigravity
```

**Implicancia operativa:**
- El grafo (`graph.json`) es portable cross-tool · si commiteas el output (opcional · ~590 KB en Forge), cualquier futuro asistente compatible lo consume sin re-procesar.
- NO obliga a estandarizar todos los equipos/freelancers en Claude Code. Si "el otro equipo" (referido en memoria `user_alejandro`) usa Cursor/Codex/Gemini CLI, pueden consumir el mismo grafo.
- Reduce lock-in a Anthropic · útil si en futuro se evalúa migración o multi-provider strategy.
- Facilita onboarding de freelancers temporales sin requerirles adoptar nuestro setup completo de skills/hooks/MCP.

---

## 🟢 medusa · due diligence externa (eval 2026-05-22)

**Repo:** https://github.com/Pantheon-Security/medusa · 568 ⭐ · AGPL-3.0
**Versión instalada:** medusa-security 2026.5.9 · venv `Desktop/_ops/medusa-env/`
**Install:**
```powershell
& "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe" -m venv "C:\Users\Administrator\Desktop\_ops\medusa-env"
& "C:\Users\Administrator\Desktop\_ops\medusa-env\Scripts\python.exe" -m pip install medusa-security
```
**Uninstall (rollback):** `Remove-Item -Recurse -Force C:\Users\Administrator\Desktop\_ops\medusa-env`

### Hallazgo crítico de la evaluación

Medusa **NO es un scanner standalone** · es un **orquestador** que delega a linters externos (ESLint · gitleaks · hadolint · shellcheck · stylelint · kube-linter · etc). Sin esos linters instalados en el venv:
- JS/TS no se escanea (JavaScriptScanner = "Tool missing")
- Solo corren los ~20 scanners Python-nativos · todos AI-focused (AIContextScanner · MCPConfigScanner · PromptLeakageScanner · etc)

### Por qué NO usar como scanner regular de verticales

| Test | Resultado |
|------|-----------|
| Scan NK · 111 archivos · 26,787 LOC · 13.12s | 54 findings · **100% falsos positivos** |
| Cobertura JS/TS real | **0%** (ESLint no instalado · y si lo instalamos, lo tenemos ya en cada vertical) |
| Cobertura CLAUDE.md (AIContextScanner) | 100% ruido · marca árboles de directorios como "GCG adversarial suffix" · code fences como "code-generation-trigger" · listas tech stack como "Payload Splitting" |
| Valor agregado vs TikiTribe + ESLint propio | Ninguno en código real |

### Por qué SÍ retener para due diligence externa

Use case PERFECTO: **scanear repos OSS antes de adoptarlos** como parte del flujo de 11 pasos de evaluación.

```powershell
& "C:\Users\Administrator\Desktop\_ops\medusa-env\Scripts\medusa.exe" scan -g user/repo
# o por URL:
& "C:\Users\Administrator\Desktop\_ops\medusa-env\Scripts\medusa.exe" scan -g https://github.com/user/repo
```

Detecta en el repo target:
- **MCPConfigScanner** · vulns en config de MCP servers de terceros
- **AIContextScanner** · prompt injection patterns en sus `.cursorrules` · `CLAUDE.md` · `AGENTS.md`
- **DatasetInjectionScanner** · payloads en sus data sources
- **CriticalCVEScanner** · CVEs conocidas en sus deps lock files
- **EnvScanner** · secrets accidentales en `.env`
- **AgentMemoryScanner** · patterns sospechosos en memory configs
- **LLMOpsScanner** · misconfigs en pipelines LLM

Para repos externos (terreno desconocido) el ruido AIContextScanner se vuelve señal · vale leer los hits manualmente.

### Cuándo correr

- **Trigger automático:** cada vez que el user pasa un nuevo repo a evaluar (workflow `/external-repos`) · agregar `medusa scan -g <repo>` antes del veredicto
- **NO correr contra:** verticales Imperium · KP · NK · RT · Sales · HR · CRM · Forge · Admin · Hub · Finance (genera 100% ruido contra sus CLAUDE.md propios)

### Notas técnicas

- Reports en JSON/HTML/markdown en `<outDir>/medusa-scan-<timestamp>.json`
- `raw-payloads.json` separado con `original_code` por finding (campo vacío en findings principales por default `--ai-safe` mode · evita que LLMs ejecuten patterns por accidente al leer reportes)
- `--fail-on critical` rompe con bug `'dict' object has no attribute 'severity'` · NO usar · usar exit code 0 + parsear JSON
- Cache en `<repo>/.medusa-cache/` · `--no-cache` para reset
- 41 FPs filtered auto (43.2%) en el scan NK · el FP filter funciona pero no captura el ruido sistémico de AIContextScanner contra docs legítimas

### Comparación con alternativas

| Tool | Caso de uso | Cuándo |
|------|-------------|--------|
| **TikiTribe rules** + Claude reading context | Reglas OWASP curadas en nuestro código | Siempre (ya activo en NK · expandir a otros verticales) |
| **ESLint + eslint-plugin-security** | Lint JS/TS de nuestros verticales | Per-vertical en CI · ya parte del stack |
| **medusa scan -g <repo>** | Due diligence pre-adopción OSS externo | Al evaluar nuevo repo · workflow integrado |
| **AgentShield** (everything-claude-code) | Reglas para AI-tooling (futuro) | Pendiente cherry-pick post-piloto |

---

## 🟡 Agendadas para sesión futura

### Agency-Agents cherry-pick (post-piloto Vet-1)

**Por qué post-piloto:** workflow actual con 3 skills + 6 subagents built-in está calibrado · no cambiar mid-sprint.

**Plan:** browse `github.com/msitarzewski/agency-agents` · seleccionar 3-5 .md candidatos · copiar manual a `~/.claude/agents/` · documentar selección.

**Candidatos identificados:**
- `engineering/code-reviewer` (o equivalente) → complementa `simplify` skill
- `finance/cfdi-mx` o `legal/lfpdppp` → para módulo Finance G.1+ con CFDI real
- `sales/sales-engineer` → revisar `Kompaws-Deck-{Cliente,Jefe}.pptx`
- `qa/qa-strategist` → ejecutar QA sweep sistemático ([[project_qa_visual_pendiente]])
- `marketing/landing-copywriter` → opcional para landing post-rebranding

---

## 🟢 Reference-only (NO instalar)

### TaxHacker

**Repo:** https://github.com/vas3k/TaxHacker (oficial · owner vas3k)

**Por qué se evaluó:** OCR + LLM extraction de facturas · stack idéntico al nuestro (Next.js 15 + Prisma + PostgreSQL + Docker · setup en 15min).

**Por qué NO se adopta:**
- Sin soporte CFDI 4.0 · gap crítico para mercado MX
- "Early development · use at your own risk" (su propio README)
- Adoptar lo ataría a stack tercero "early dev"

**Cuándo leer su código:** cuando se diseñe la feature OCR de Finance G.1+ · clonar temporal · leer `prisma/schema.prisma` + ruta de OCR · documentar hallazgos en `00-DOCS-MAESTRAS/` · borrar clone.

---

## ⚪ Descartadas / decisión firme

### oh-my-claudecode (OMC)

**Decisión inicial:** 2026-05-04 (memoria `[[feedback_wigflow_omc_adoption_2026-05-04]]`).
**Re-evaluación:** N°28 (2026-05-13) · sigue válida.

**Razones:**
- tmux dependency · doloroso en Windows native
- Sobre-ingeniería para workflow ya calibrado
- Conflict potencial con skills custom y memoria curada
- Cost optimization claim (30-50% tokens) no compensa riesgo de regresión

**Sandbox:** El otro equipo (per memoria `user_alejandro` · no documentado nombre exacto) tiene OMC v4.13.5 instalado · sirve como entorno experimental sin tocar este equipo crítico.

**Re-abrir cuándo:** Post-piloto Vet-1 estable · si el otro equipo demuestra valor claro y consistente · NO durante sprint activo.

---

---

## 📋 Evaluación batch 2026-05-14 · 8 repos sugeridos por user

| # | Repo | ⭐ | Veredicto | Razón corta |
|---|---|---|---|---|
| 1 | [thedotmack/claude-mem](https://github.com/thedotmack/claude-mem) | 75.7k | 🟡 reference-only | Memoria persistente cross-sesión vía MCP · puerto 37777 (¡ya reservado en `PORTS.md`!) · pero overlap con auto-memory built-in que ya usamos (108+ .md en `~/.claude/projects/.../memory/`). Ver § Claude-Mem abajo. |
| 2 | [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) | 78.4k | 🟢 **TRY antes del QA visual sweep** | 161 reasoning rules + 67 UI styles + 161 palettes + 57 font pairings + 99 UX guidelines. Cross-IDE (16+ assistants). Acelera el `[[project_qa_visual_pendiente]]` sweep N°30+ · matchea bien el roadmap (rebranding Almena/Sceptra + cliente Vet-1 demos). |
| 3 | [HKUDS/LightRAG](https://github.com/HKUDS/LightRAG) | 35.2k | 🟡 agendado post-piloto Vet-1 | RAG con knowledge graph + dual-level retrieval · 45-85% mejor que GraphRAG/HyDE. Stack pesado (Python · LLM 32B+ · 32K+ context). Útil SI Vet-1 pide búsqueda semántica de expedientes clínicos / Q&A docs · NO antes. |
| 4 | [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code) | 140k | 🟡 cherry-pick · evaluar AgentShield | Anthropic Hackathon Winner Feb 2026. 60+ agents · 228+ skills · 75+ commands · AgentShield (1,282 tests · 102 rules). Bulk install satura (mismo argumento que Agency-Agents). Cherry-pick AgentShield como reemplazo/complemento de `TikiTribe/claude-secure-coding-rules`. |
| 5 | [sickn33/antigravity-awesome-skills](https://github.com/sickn33/antigravity-awesome-skills) | 37.5k | 🟡 cherry-pick post-piloto | 1,459+ skills cross-IDE en 5 categorías. Mismo patrón que Agency-Agents · NO bulk install · cherry-pick específicos (DevOps · Security · Testing). Ver `CATALOG.md` para browse. |
| 6 | [FlorianBruniaux/claude-code-ultimate-guide](https://github.com/FlorianBruniaux/claude-code-ultimate-guide) | 4.3k | 🟢 reference-only · bookmark | 24K líneas guía + 181 templates + 271 quiz + 151 evaluaciones + 28 CVEs trackeados. CC-BY-SA-4.0. EN + FR. Useful para profundizar Claude Code sin instalar nada. Buen recurso onboarding nuevos devs. |
| 7 | [Hainrixz/claude-webkit](https://github.com/Hainrixz/claude-webkit) | 130 | 🟡 reference-only | Genera landings Next.js 15 + Tailwind 4 + shadcn + Framer. Workflow CLI con cuestionario + Vercel deploy. **NO migrar verticales** (stack distinto · usamos Vite+React). Útil para landing público Almena/Sceptra/Kompaws si se decide hacer marketing site en Next.js. |
| 8 | [obra/superpowers](https://github.com/obra/superpowers) | **191k** | ✅ **ADOPTED N°29 · uso quirúrgico** | Plugin instalado y validado en sandbox (validateRfc · 13 tests TDD · 0 conflictos skills propios). Función portada a `Imperium_Sales/utils/`. Uso QUIRÚRGICO confirmado: skills útiles (writing-plans · TDD · git-worktrees · systematic-debugging) ✅ · `:brainstorming` solo en features ambiguas reales (sobre-pregunta · ver `[[feedback_brainstorming_only_when_ambiguous]]`) · ver memoria `project_superpowers_adopted_2026-05-14` para tabla skill-by-skill. |

### Claude-Mem · análisis profundo (overlap con auto-memory built-in)

**Argumentos PRO adoptar:**
- Puerto 37777 ya reservado en `PORTS.md` (sesión vieja contempló esto · señal de que se ha pensado antes)
- Web viewer real-time en `localhost:37777` para browse memorias (UX > leer .md a mano)
- Hybrid SQLite full-text + Chroma vector embeddings · búsqueda semántica > grep
- Progressive disclosure reduce ~10x tokens vs cargar memoria completa
- `<private>` tags para excluir secrets de storage
- Cross-tool: Gemini CLI + OpenCode además de Claude Code

**Argumentos CONTRA adoptar:**
- Auto-memory built-in YA funciona (108+ .md en `~/.claude/projects/.../memory/` · indexado en `MEMORY.md` · Claude lee automáticamente al iniciar sesión)
- Backup integrado al daily desde N°28 (`backup-daily.ps1` step `claude-config`)
- Claude-mem requiere Bun + Python uv + Chroma · stack adicional vs solo .md
- Riesgo de duplicar memoria · qué es source of truth si ambos están activos
- Migración: 108 .md actuales tendrían que convertirse o convivir

**Decisión sugerida:** **NO adoptar ahora** · re-evaluar SI:
- Auto-memory crece >500 .md y MEMORY.md (índice) se vuelve inmanejable
- Necesitamos search semántico cross-sesión que grep no resuelve
- Otro equipo/freelancer onboarda y necesita explorar memoria con UI visual

Liberar puerto 37777 de `PORTS.md` o documentar que sigue reservado para potencial claude-mem futuro.

### UI/UX Pro Max · plan de evaluación

**Cuándo:** Antes de la sesión "Quality day" (Opción C del activador N°30) · O en sesión de rebranding NK→Almena post-IMPI.

**Cómo:**
1. `npm install -g uipro-cli` (Node.js disponible)
2. `uipro init --ai claude` en un vertical de prueba (ej `Imperium_Hr/client/`)
3. Generar design system para HR (industria: Tech & SaaS)
4. Comparar con paleta actual · adoptar lo que mejore
5. Si rinde: aplicar al QA visual sweep de los 6 verticales

**Risk bajo · install no destructivo · skill se invoca opcionalmente.**

### Superpowers · plan de evaluación

**Cuándo:** Antes de N°30 si se elige Opción A (HR frontend) · el TDD enforce + brainstorming workflow ayudan en feature work nuevo.

**Cómo:**
1. `/plugin install superpowers@claude-plugins-official` (plugin marketplace oficial)
2. Probar en una task nueva no crítica (ej landing page o feature corto)
3. Evaluar si el brainstorming + TDD enforce mejoran calidad sin frenar
4. Si rinde: hacer default · si frena: usar opcional para features grandes solamente

**Caveat:** plugin oficial = tooling estable · pero puede chocar con nuestros skills custom (verify-fix-loop · simplify). Probar en isolation primero.

---

## 🔄 Flujo de decisión para tools nuevos

Cuando aparezca un repo/tool nuevo a evaluar:

1. **Categorizar:** ¿Workflow tool · referencia · standalone util?
2. **Verificar stack contra Imperium:** Node/React/Prisma/Postgres = afín · Python/Rust/Go = fricción
3. **Verificar deps externas:** tmux, Docker, Python venv = añaden ops
4. **Verificar madurez:** ⭐ count, último commit, issues abiertos, "production-ready" claims
5. **Comparar contra alternativas existentes:** ¿Reemplaza una skill o duplica?
6. **Identificar elemento controlado:** ¿dónde se va a probar sin afectar productivos? (vertical prueba · feature no-crítica · sandbox · branch separado · plugin install reversible)
7. **Documentar rollback path:** una línea con cómo desinstalar/revertir SI rompe algo (`pipx uninstall X` · `/plugin uninstall Y` · `rm -rf <dir>`)
8. **Decidir:** ✅ install (en elemento controlado) · 🟡 agendar · 🟢 reference · ⚪ descartar
9. **Si se prueba y rinde:** documentar métricas reales + mover a sección ✅ Activos (igual que Graphify N°29)
10. **Si se prueba y falla:** revertir primero (volver a estado verde) · investigar root cause con calma · documentar hallazgo en `[[project_external_tools_eval_*]]` (NO solo descartar y olvidar · ese aprendizaje queda)
11. **Capturar en este doc + en `[[project_external_tools_eval_*]]`** sesión correspondiente

**Reglas firmes:**
- **No instalar tools mid-sprint sin razón concreta.** Tooling adoption es decisión separada de feature work.
- **Adopción controlada vale como adopción legítima.** No descartar a priori solo por riesgo · si hay rollback path claro, probar en sandbox.
- **Post-rollback ≠ archivar y olvidar.** Un tool que falló enseña por qué falló · ese conocimiento se documenta para futuras evaluaciones similares.
- Ver memoria autoritativa: `[[feedback_tool_adoption_controlled_rollback]]` (2026-05-14)

---

## 🟢 charts · Chart.js vía Forge `@nomadknight/charts` (N°85 · 2026-06-01)

**Externo adoptado:** `chart.js`@4.5.1 + `react-chartjs-2`@5.3.1 — **ambos MIT** ✅ (vendibles · se sirven al cliente, no son dev-tool).

**Vehículo de consumo (interno):** paquete Forge `Imperium_Forge/packages/extensions/charts` (`@nomadknight/charts`) — wrapper premium estilo Hub (gradiente + sombras + glow-cap + monospace), accent/tono por vertical via CSS var. peerDeps: react, chart.js, react-chartjs-2.

**Por qué:** reemplaza los `RevenueChart` SVG **clonados** en ~8 verticales (deuda template-clone) por un componente compartido. Mejor UX (tooltips reales) + identidad consistente.

**Estado:** adoptado en **Kompaws** (piloto/reel). Pusheado: Forge `3940953` + Kompaws `eed8b4d`. Rollout a 7 verticales **planeado, diferido** (reframe) → `00-DOCS-MAESTRAS/CHARTS_ROLLOUT_2026-06-01.md`.

**Rollback (por vertical):** `git checkout Negocio.jsx package.json` + `npm uninstall chart.js react-chartjs-2 @nomadknight/charts`. El SVG viejo vive en git history. Eliminar el paquete = borrar `packages/extensions/charts`.

**Due diligence:** medusa scan de chart.js (N°85) → GitLeaks/CVE/MCP-RCE limpios. Ver `[[feedback_license_gate_para_venta]]`.
