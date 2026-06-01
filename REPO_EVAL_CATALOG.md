# Catálogo de Repos Externos Evaluados · Imperium
> **Uso interno · reutilizable cross-proyecto.** Cada repo externo que se analiza se guarda aquí con su ficha (área · uso · licencia · veredicto venta · medusa).
> Propósito: poder reusar/adoptar en CUALQUIER proyecto futuro sin re-analizar.
> Complementa: `RESEARCH_LOG.md` (referencias por feature) · `EXTERNAL_TOOLS.md` (lo ya instalado).
> Regla de licencia → venta: ver memoria `feedback_license_gate_para_venta` y `LICENSE_AUDIT_2026-06-01.md`.

## Leyenda
- **Uso**: 🟢 bundle (se sirve al cliente → licencia debe ser permisiva) · 🔵 dev-tool (interno, no se distribuye → copyleft OK) · ⚪ referencia (solo consultar)
- **¿Vender?**: ✅ permisivo, vendible · ⚠️ condicional · 🔴 bloquea
- **⚠️ IA**: licencia del código ≠ licencia de los PESOS del modelo (verificar weights aparte para uso comercial)

---

## Batch 2026-06-01 (Sesión N°85)

| # | Repo | Área | Para qué sirve | Licencia | ¿Vender? | Uso | Veredicto |
|---|---|---|---|---|---|---|---|
| 1 | [RyanCodrai/turbovec](https://github.com/RyanCodrai/turbovec) | construir | Índice vectorial (búsqueda semántica/RAG), Rust+Python | MIT | ✅ | 🟢 | OK, pero prefiere **pgvector** (ya usas Postgres). turbovec es nicho |
| 2 | [reconurge/flowsint](https://github.com/reconurge/flowsint) | seguridad/diseñar | Investigaciones OSINT con grafos visuales | Apache-2.0 | ✅ | 🟢/🔵 | OK. Encaje solo si construyes vertical de seguridad/OSINT |
| 3 | [zjunlp/SkillNet](https://github.com/zjunlp/SkillNet) | construir | Crear/evaluar/conectar AI skills | MIT | ✅ | 🔵 | OK dev-tool. Encaje marginal (ya tienes superpowers) |
| 4 | [tinyhumansai/openhuman](https://github.com/tinyhumansai/openhuman) | construir | Asistente IA personal (Rust) | **GPL-3.0** | ⚠️ solo SaaS | 🔵 no-bundle | NO bundlear al producto. On-prem futuro → contamina. Preferir propio |
| 5 | [Hack-with-Github/Awesome-Hacking](https://github.com/Hack-with-Github/Awesome-Hacking) | seguridad | Lista de recursos hardening/pentest | CC0 (dominio público) | ✅ | ⚪ | Consultar libremente |
| 6 | [chartjs/Chart.js](https://github.com/chartjs/Chart.js) | diseñar/construir | Gráficas HTML5 en dashboards (hoy SVG a mano) | MIT | ✅ | 🟢 | **★ Mejor encaje inmediato.** medusa: 0 secretos/CVE/RCE |
| 7 | [abi/screenshot-to-code](https://github.com/abi/screenshot-to-code) | construir/diseñar | Screenshot→código (HTML/Tailwind/React) | MIT | ✅ | 🔵 | OK dev-tool. Manda screenshots a LLM (API key) |
| 8 | [obra/superpowers](https://github.com/obra/superpowers) | construir | Framework agentic skills + metodología | MIT | ✅ | 🔵 | **YA ADOPTADO** N°29 (uso quirúrgico) |
| 9 | [ultraworkers/claw-code](https://github.com/ultraworkers/claw-code) | construir | Agente de código (Rust) | MIT | ✅* | 🚩 | **DESCARTAR.** ★ sospechosos (manipulación), compite con Claude Code, aporte nulo. Si algún día → medusa obligatorio |
| 10 | [nilbuild/developer-roadmap](https://github.com/nilbuild/developer-roadmap) | referencia/marketing | Roadmaps de aprendizaje | **NOASSERTION (restrictiva)** | ⚪ no copiar | ⚪ | Consultar; NO redistribuir su contenido |
| 11 | [cporter202/API-mega-list](https://github.com/cporter202/API-mega-list) | referencia | Catálogo de APIs (PAC, pagos, etc.) | **SIN LICENCIA** | ⚪ no copiar | ⚪ | Consultar; NO copiar la lista a tu repo |
| 12 | [KeygraphHQ/shannon](https://github.com/KeygraphHQ/shannon) | seguridad | Pentester IA white-box de tus apps | **AGPL-3.0** | ✅ si interno | 🔵 dev-only | OK como herramienta interna (pentest pre-cliente). NUNCA servir/ofrecer como feature. medusa: 0 secretos/CVE |
| 13 | [mukul975/cve-mcp-server](https://github.com/mukul975/cve-mcp-server) | seguridad | MCP: CVE/EPSS/KEV/ATT&CK/Shodan/VT para tu asistente | Apache-2.0 | ✅ | 🔵 | OK. Complementa medusa. medusa: 0 secretos/CVE/MCP-RCE |
| 14 | [adithya-s-k/omniparse](https://github.com/adithya-s-k/omniparse) | construir | Parsear PDFs/docs/media para GenAI | **GPL-3.0** | ⚠️ solo SaaS | 🟢/🔵 | Para feature vendible preferir **markitdown (MIT)** o **docling (MIT)** o propio |
| 15 | [NVlabs/Eagle](https://github.com/NVlabs/Eagle) | construir | Vision-Language Model (analizar imágenes) | Apache-2.0 (código) | ⚠️ **weights** | 🟢 | Verificar licencia de PESOS antes de uso comercial (NVIDIA suele no-comercial) |
| 16 | [lightningpixel/modly](https://github.com/lightningpixel/modly) | diseñar/construir | Imagen→3D local (GPU) | MIT (código) | ⚠️ **weights** | 🟢 | Verificar licencia del modelo subyacente. Encaje bajo para verticales actuales |

### Alternativas permisivas (si el original bloquea)
| Bloqueado/riesgo | Alternativa para construir/vender |
|---|---|
| omniparse (GPL) | markitdown (MIT) · docling (MIT) · propio |
| openhuman (GPL) | propio sobre SDKs permisivos |
| turbovec (nicho) | pgvector (ya tienes PG) · sqlite-vec |
| Eagle/modly (weights) | modelo con licencia comercial (ej. Florence-2 MIT) |

### Mejor encaje neto para el negocio actual
1. **Chart.js** → producto (dashboards), adoptar.
2. **cve-mcp-server** + **shannon** → seguridad interna (gate pre-cliente Bloque 1).
Resto: nicho, dev-tool o referencia.

### Nota medusa (2026-06-01)
Scanners deterministas (GitLeaks/CriticalCVE/MCP-RCE) = **limpios** en Chart.js, cve-mcp-server, shannon. Triage por severidad NO disponible por bug de medusa (`'dict' object has no attribute 'severity'` / `no_ai_safe not defined`) — deuda del tool. Conteos heurísticos LLM altos = falsos positivos esperables (shannon/cve-mcp contienen payloads por diseño). Revisar a mano scanners de alto valor del elegido antes de adoptar.

---

## Cómo extender este catálogo
Por cada repo externo nuevo analizado: agregar fila con **área · para qué sirve · licencia (verificada en el archivo, no de memoria) · ¿vendible? · uso (bundle/dev/ref) · veredicto**. Si es candidato de adopción real: correr `medusa scan -g <repo>` y anotar resultado. Mantener el gate de licencias (`feedback_license_gate_para_venta`).
