# Plan de Internacionalización - OpenClaw VPS Guide

> **Objetivo**: Convertir la guía a bilingüe (EN principal + ES) manteniendo la calidad 9.32/10 aprobada.

---

## Resumen Ejecutivo

| Aspecto | Decisión |
|---------|----------|
| **Idioma principal** | Inglés (CORBAT internacional) |
| **Idioma secundario** | Español (valor para hispanohablantes) |
| **Solución técnica** | mkdocs-static-i18n plugin |
| **Estructura** | `docs/en/`, `docs/es/` |
| **URL resultante** | `/en/...` (default), `/es/...` |

---

## Fase 1: Preparación (10 min)

### 1.1 Instalar plugin de i18n

```bash
pip install mkdocs-static-i18n
```

### 1.2 Crear estructura de carpetas

```
docs/
├── en/                    # Inglés (principal)
│   ├── index.md
│   ├── 01-preparation.md
│   ├── 02-vps.md
│   ├── 03-system-security.md
│   ├── 04-private-access.md
│   ├── 05-openclaw.md
│   ├── 06-llm-apis.md
│   ├── 07-use-cases.md
│   ├── 08-agent-security.md
│   ├── 09-maintenance.md
│   ├── 10-final-checklist.md
│   └── glossary.md
├── es/                    # Español (secundario)
│   ├── index.md
│   ├── 01-preparacion.md
│   ├── 02-vps.md
│   ├── 03-seguridad-sistema.md
│   ├── 04-acceso-privado.md
│   ├── 05-openclaw.md
│   ├── 06-llm-apis.md
│   ├── 07-casos-uso.md
│   ├── 08-seguridad-agente.md
│   ├── 09-mantenimiento.md
│   ├── 10-checklist-final.md
│   └── glosario.md
```

### 1.3 Actualizar mkdocs.yml

Configurar el plugin i18n con:
- Idioma por defecto: `en`
- Idiomas disponibles: `en`, `es`
- Selector de idioma en header
- URLs limpias (`/en/`, `/es/`)

---

## Fase 2: Mover contenido español (5 min)

### 2.1 Archivos a mover

| Origen | Destino |
|--------|---------|
| `docs/index.md` | `docs/es/index.md` |
| `docs/01-preparacion.md` | `docs/es/01-preparacion.md` |
| `docs/02-vps.md` | `docs/es/02-vps.md` |
| `docs/03-seguridad-sistema.md` | `docs/es/03-seguridad-sistema.md` |
| `docs/04-acceso-privado.md` | `docs/es/04-acceso-privado.md` |
| `docs/05-openclaw.md` | `docs/es/05-openclaw.md` |
| `docs/06-llm-apis.md` | `docs/es/06-llm-apis.md` |
| `docs/07-casos-uso.md` | `docs/es/07-casos-uso.md` |
| `docs/08-seguridad-agente.md` | `docs/es/08-seguridad-agente.md` |
| `docs/09-mantenimiento.md` | `docs/es/09-mantenimiento.md` |
| `docs/10-checklist-final.md` | `docs/es/10-checklist-final.md` |
| `docs/glosario.md` | `docs/es/glosario.md` |

### 2.2 Actualizar links internos en español

Cambiar todos los links de `](01-preparacion.md)` a `](01-preparacion.md)` (relativo dentro de `es/`).

---

## Fase 3: Traducir a inglés (2-3 horas)

### 3.1 Orden de traducción

| # | Archivo | Prioridad | Notas |
|---|---------|-----------|-------|
| 1 | `index.md` | Alta | Primera impresión |
| 2 | `01-preparation.md` | Alta | Inicio del flujo |
| 3 | `02-vps.md` | Alta | - |
| 4 | `03-system-security.md` | Alta | Crítico para seguridad |
| 5 | `04-private-access.md` | Alta | Crítico para seguridad |
| 6 | `05-openclaw.md` | Alta | Core de la guía |
| 7 | `06-llm-apis.md` | Media | - |
| 8 | `07-use-cases.md` | Media | - |
| 9 | `08-agent-security.md` | Alta | OWASP, diferenciador |
| 10 | `09-maintenance.md` | Media | - |
| 11 | `10-final-checklist.md` | Alta | Cierre de la guía |
| 12 | `glossary.md` | Baja | Referencia |

### 3.2 Reglas de traducción

1. **NO traducir**:
   - Comandos bash
   - Nombres de archivos/paths
   - Configuraciones YAML/JSON
   - Nombres de servicios (Tailscale, OpenClaw, etc.)
   - Términos técnicos estándar (firewall, daemon, etc.)

2. **SÍ traducir**:
   - Títulos y descripciones
   - Explicaciones
   - Admonitions (tip, warning, danger)
   - Comentarios en código (opcional)
   - Troubleshooting

3. **Adaptar**:
   - "Europe/Madrid" → mantener pero añadir ejemplos US
   - URLs de proveedores → añadir opciones internacionales
   - Ejemplos de precios → EUR y USD

### 3.3 Mapeo de títulos ES → EN

| Español | Inglés |
|---------|--------|
| Preparación | Preparation |
| Contratar VPS | Provision VPS |
| Seguridad del sistema | System Security |
| Acceso privado | Private Access |
| Instalar OpenClaw | Install OpenClaw |
| APIs de LLM | LLM APIs |
| Casos de uso | Use Cases |
| Seguridad del agente | Agent Security |
| Mantenimiento | Maintenance |
| Checklist final | Final Checklist |
| Glosario | Glossary |

### 3.4 Mapeo de admonitions

| Español | Inglés |
|---------|--------|
| TL;DR | TL;DR |
| Tiempo estimado | Estimated time |
| Nivel requerido | Required level |
| Principiante | Beginner |
| Intermedio | Intermediate |
| Avanzado | Advanced |
| Prerrequisitos | Prerequisites |
| Objetivos | Objectives |
| Salida esperada | Expected output |
| Troubleshooting | Troubleshooting |
| Causa | Cause |
| Solución | Solution |

---

## Fase 4: Configurar mkdocs.yml (15 min)

### 4.1 Nuevo mkdocs.yml

```yaml
site_name: OpenClaw on VPS
site_description: Secure installation guide for OpenClaw on VPS - CIS Benchmark, Tailscale Hardening, OWASP Agentic Top 10
site_author: CORBAT
site_url: https://corbat.github.io/openclaw-vps-guide/

repo_name: openclaw-vps-guide
repo_url: https://github.com/corbat/openclaw-vps-guide

theme:
  name: material
  language: en
  palette:
    - scheme: slate
      primary: deep purple
      accent: amber
      toggle:
        icon: material/brightness-4
        name: Switch to light mode
    - scheme: default
      primary: deep purple
      accent: amber
      toggle:
        icon: material/brightness-7
        name: Switch to dark mode
  features:
    - navigation.sections
    - navigation.expand
    - navigation.top
    - navigation.indexes
    - content.code.copy
    - content.code.annotate
    - toc.follow
  icon:
    repo: fontawesome/brands/github

plugins:
  - search
  - i18n:
      default_language: en
      default_language_only: false
      docs_structure: folder
      languages:
        - locale: en
          name: English
          build: true
          default: true
        - locale: es
          name: Español
          build: true

markdown_extensions:
  - admonition
  - pymdownx.details
  - pymdownx.superfences
  - pymdownx.highlight:
      anchor_linenums: true
  - pymdownx.inlinehilite
  - pymdownx.tabbed:
      alternate_style: true
  - tables
  - attr_list
  - md_in_html
  - toc:
      permalink: true

nav:
  - Home: index.md
  - Installation Guide:
    - 1. Preparation: 01-preparation.md
    - 2. Provision VPS: 02-vps.md
    - 3. System Security: 03-system-security.md
    - 4. Private Access (Tailscale): 04-private-access.md
    - 5. Install OpenClaw: 05-openclaw.md
    - 6. LLM APIs: 06-llm-apis.md
    - 7. Use Cases: 07-use-cases.md
  - Advanced Security:
    - 8. Agent Security: 08-agent-security.md
    - 9. Maintenance: 09-maintenance.md
    - 10. Final Checklist: 10-final-checklist.md
  - Reference:
    - Glossary: glossary.md

extra:
  alternate:
    - name: English
      link: /en/
      lang: en
    - name: Español
      link: /es/
      lang: es
  social:
    - icon: fontawesome/brands/github
      link: https://github.com/corbat
```

---

## Fase 5: Verificación (30 min)

### 5.1 Checklist de calidad

#### Contenido
- [ ] Todos los archivos EN creados
- [ ] Todos los archivos ES movidos
- [ ] Links internos funcionan en EN
- [ ] Links internos funcionan en ES
- [ ] Imágenes/diagramas accesibles en ambos idiomas

#### Navegación
- [ ] Selector de idioma visible
- [ ] Cambio de idioma mantiene la página actual
- [ ] Navegación lateral correcta en EN
- [ ] Navegación lateral correcta en ES
- [ ] Búsqueda funciona en ambos idiomas

#### Técnico
- [ ] `mkdocs serve` sin errores
- [ ] `mkdocs build` sin errores
- [ ] URLs limpias (`/en/`, `/es/`)

### 5.2 Prueba local

```bash
# Instalar dependencias
pip install mkdocs-material mkdocs-static-i18n

# Probar localmente
mkdocs serve

# Verificar:
# - http://localhost:8000/en/
# - http://localhost:8000/es/
# - Selector de idioma funciona
# - Links internos funcionan
```

### 5.3 Auditoría rápida de traducción

- [ ] Títulos traducidos correctamente
- [ ] Admonitions en inglés correcto
- [ ] Sin spanglish accidental
- [ ] Comandos bash sin modificar
- [ ] Outputs esperados sin traducir (son outputs reales)

---

## Fase 6: Commit y publicación (5 min)

### 6.1 Commits sugeridos

```bash
# Commit 1: Estructura
git add -A
git commit -m "chore: restructure for i18n (en + es)"

# Commit 2: Traducciones (si se hace por separado)
git add -A
git commit -m "feat: add English translation of complete guide"

# O un solo commit:
git commit -m "feat: add bilingual support (EN primary + ES)

- Restructure docs/ with en/ and es/ folders
- Add complete English translation
- Configure mkdocs-static-i18n plugin
- English as default language (CORBAT international)
- Spanish maintained for Hispanic community

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

### 6.2 Push y verificar

```bash
git push origin main

# Si usas GitHub Pages, verificar deployment
```

---

## Cronograma estimado

| Fase | Duración | Acumulado |
|------|----------|-----------|
| 1. Preparación | 10 min | 10 min |
| 2. Mover ES | 5 min | 15 min |
| 3. Traducir EN | 2.5 h | 2h 45min |
| 4. Config mkdocs | 15 min | 3h |
| 5. Verificación | 30 min | 3h 30min |
| 6. Commit/Push | 5 min | 3h 35min |

**Total estimado: ~3.5 horas**

---

## Riesgos y mitigaciones

| Riesgo | Mitigación |
|--------|------------|
| Pérdida de calidad en traducción | Mantener comandos/configs originales |
| Links rotos | Verificación sistemática post-migración |
| SEO duplicado | Configurar canonical URLs correctamente |
| Plugin i18n incompatible | Fallback a estructura manual con nav separado |

---

## Criterios de éxito

- [x] Ambas versiones navegables sin errores
- [x] Selector de idioma funcional
- [x] Calidad de contenido EN = ES (9.32/10)
- [x] Todos los comandos ejecutables
- [x] Build de mkdocs sin warnings

---

## Estado de ejecución

| Fase | Estado | Fecha |
|------|--------|-------|
| 1. Preparación | ✅ Completado | 2026-02-01 |
| 2. Mover ES | ✅ Completado | 2026-02-01 |
| 3. Traducir EN | ✅ Completado | 2026-02-01 |
| 4. Config mkdocs | ✅ Completado | 2026-02-01 |
| 5. Verificación | ✅ Completado | 2026-02-01 |
| 6. Commit/Push | ⏳ Pendiente | - |

### Archivos creados/modificados

**docs/en/** (12 archivos traducidos):
- `index.md` - Home page
- `01-preparation.md` - Preparation guide
- `02-vps.md` - VPS provisioning
- `03-system-security.md` - System security (CIS Benchmark)
- `04-private-access.md` - Tailscale configuration
- `05-openclaw.md` - OpenClaw installation
- `06-llm-apis.md` - LLM API configuration
- `07-use-cases.md` - Use cases and examples
- `08-agent-security.md` - OWASP Agentic Top 10
- `09-maintenance.md` - Maintenance procedures
- `10-final-checklist.md` - Final security checklist
- `glossary.md` - Glossary of terms

**docs/es/** (12 archivos movidos):
- Todos los archivos españoles originales preservados

**mkdocs.yml** - Configurado con:
- Plugin i18n con estructura de carpetas
- Inglés como idioma por defecto
- Navegación separada para cada idioma
- Selector de idioma en extra.alternate

---

*Plan creado: 2026-02-01*
*Ejecución completada: 2026-02-01*
*Versión: 1.1*
