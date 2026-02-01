# Prompt de Auditoría Exhaustiva - OpenClaw VPS Guide

> **Uso**: Cuando el usuario diga "haz una auditoría" o "pasa una auditoría", ejecuta este protocolo completo.

---

## PROTOCOLO DE AUDITORÍA

### PASO 0: Leer Estado Anterior (OBLIGATORIO)

```
Lee PRIMERO el archivo AUDIT_LOG.md para:
1. Conocer la puntuación actual
2. Ver qué problemas ya fueron corregidos (NO repetir trabajo)
3. Identificar problemas pendientes prioritarios
4. Verificar el número de iteración actual
5. Evaluar si estamos cerca de convergencia
```

**Si no existe AUDIT_LOG.md**, créalo con la estructura base.

---

### PASO 1: Leer Documentación (en orden)

```
Archivos a leer:
1. docs/index.md
2. docs/01-preparacion.md
3. docs/02-vps.md
4. docs/03-seguridad-sistema.md
5. docs/04-acceso-privado.md
6. docs/05-openclaw.md
7. docs/06-llm-apis.md
8. docs/07-casos-uso.md
9. docs/08-seguridad-agente.md
10. docs/09-mantenimiento.md
11. docs/10-checklist-final.md
12. docs/glosario.md
13. mkdocs.yml
14. PLAN_MEJORA_GUIA.md (objetivos originales)
```

---

### PASO 2: Evaluar 13 Criterios

Puntúa cada criterio de 1-10:

| # | Criterio | Qué evaluar |
|---|----------|-------------|
| 1 | **Completitud** | ¿Faltan pasos críticos? ¿Hay gaps en el flujo? |
| 2 | **Claridad** | ¿Un dev junior puede seguirla sin ayuda externa? |
| 3 | **Brevedad** | ¿Hay redundancia innecesaria entre secciones? |
| 4 | **Seguridad VPS (CIS)** | Comparar con CIS Benchmark Ubuntu 24.04 L1 |
| 5 | **Seguridad VPS (Tailscale)** | Comparar con Tailscale Security Hardening docs |
| 6 | **Seguridad Agente (OWASP)** | Comparar con OWASP Agentic Top 10 2026 + LLM Top 10 2025 |
| 7 | **Systemd Hardening** | ¿El servicio tiene sandboxing adecuado? |
| 8 | **Comandos** | ¿Son correctos, testeables y copy-paste friendly? |
| 9 | **Verificaciones** | ¿Cada paso crítico tiene comando de verificación con output esperado? |
| 10 | **Troubleshooting** | ¿Los errores comunes están documentados con soluciones? |
| 11 | **Mantenibilidad** | ¿Versiones especificadas? ¿Fecha de verificación? ¿Links funcionales? |
| 12 | **Consistencia** | ¿Placeholders uniformes? ¿Formato consistente entre archivos? |
| 13 | **Actualización** | ¿Info de 2026 correcta? (modelos LLM, versiones de software) |

**Fórmula de puntuación global**:
```
TOTAL = (Criterios 1-3 + Criterios 8-13) * 1.0 + (Criterios 4-7) * 1.5
        ─────────────────────────────────────────────────────────────
                                    13 + 4*0.5
```
(Seguridad tiene peso 1.5x)

---

### PASO 3: Identificar Problemas

Clasifica cada problema encontrado:

| Severidad | Descripción | Acción |
|-----------|-------------|--------|
| 🔴 **CRÍTICO** | Riesgo de seguridad o pérdida de acceso | DEBE corregirse antes de publicar |
| 🟡 **MEDIO** | Error funcional o confusión significativa | DEBERÍA corregirse |
| 🟢 **BAJO** | Mejora de calidad, typo, formato | PUEDE corregirse |

**Formato de problema**:
```
| ID | Severidad | Archivo:línea | Problema | Solución propuesta |
```

---

### PASO 4: Comparar con Auditoría Anterior

```
1. ¿Se resolvieron los problemas pendientes (A#-P##)?
2. ¿Aparecieron nuevos problemas?
3. ¿Mejoró o empeoró la puntuación?
4. Calcular DELTA = Puntuación_actual - Puntuación_anterior
```

---

### PASO 5: Aplicar Correcciones

**Reglas**:
1. Corregir TODOS los problemas 🔴 CRÍTICOS inmediatamente
2. Corregir problemas 🟡 MEDIOS si hay menos de 5
3. Problemas 🟢 BAJOS: corregir los de mayor impacto (máx 3)
4. Documentar cada cambio realizado

---

### PASO 6: Evaluar Convergencia

```python
if delta < 0.1 and zero_critical and zero_medium:
    if consecutive_stable_audits >= 3:
        PROPONER_VERSION_FINAL()
    else:
        consecutive_stable_audits += 1
else:
    consecutive_stable_audits = 0
```

---

### PASO 7: Actualizar AUDIT_LOG.md

Añadir nueva entrada con:

```markdown
### Auditoría #N - YYYY-MM-DD

**Auditor**: [nombre del modelo]
**Puntuación anterior**: X.XX/10
**Puntuación actual**: X.XX/10
**Delta**: +/-X.XX

#### Problemas encontrados y resueltos:
[tabla de problemas corregidos]

#### Problemas pendientes para siguiente auditoría:
[tabla de problemas que quedan]

#### Delta de cambio: X.XX puntos
```

Actualizar también:
- Tabla de "Estado Actual" al inicio
- Sección "Estado de Convergencia"
- "Próximos Pasos Sugeridos"

---

### PASO 8: Generar Informe Final

Producir informe con estas secciones:

```markdown
# INFORME DE AUDITORÍA #N

## 1. Resumen Ejecutivo
- Puntuación: X.XX/10 (anterior: X.XX)
- Delta: +/-X.XX
- Estado de convergencia: [X/3 auditorías estables]

## 2. Tabla de Puntuaciones
[13 criterios con justificación]

## 3. Cumplimiento de Estándares
- CIS Benchmark L1: XX%
- Tailscale Hardening: XX%
- OWASP Agentic: XX%

## 4. Problemas Corregidos en Esta Auditoría
[lista con IDs]

## 5. Problemas Pendientes
[lista priorizada]

## 6. Cambios Realizados
[diff resumido de cada archivo modificado]

## 7. Recomendación
- [ ] Continuar iterando
- [ ] PROPONER VERSIÓN FINAL

## 8. Próximos Pasos
[3-5 acciones concretas para siguiente auditoría]
```

---

## CRITERIOS DE VERSIÓN FINAL

Cuando se cumplan TODOS estos criterios, proponer versión final:

### Obligatorios:
- [ ] Puntuación ≥ 9.3/10
- [ ] CIS Benchmark L1 = 100%
- [ ] OWASP Agentic ≥ 90%
- [ ] 0 problemas 🔴 CRÍTICOS
- [ ] 0 problemas 🟡 MEDIOS
- [ ] 3 auditorías consecutivas con delta < 0.1

### Al proponer versión final:

```markdown
## 🎉 VERSIÓN FINAL PROPUESTA

Esta guía ha alcanzado estabilidad después de [N] auditorías.

**Puntuación final**: X.XX/10
**Conformidad**:
- CIS Benchmark Ubuntu 24.04 L1: 100%
- Tailscale Security Hardening: XX%
- OWASP Agentic Top 10 2026: XX%

**Historial de convergencia**:
- Auditoría #N-2: X.XX (delta: X.XX)
- Auditoría #N-1: X.XX (delta: X.XX)
- Auditoría #N: X.XX (delta: X.XX) ← ESTABLE

**Problemas menores aceptados** (no bloquean publicación):
[lista de issues 🟢 que se aceptan como están]

**Recomendación**: ✅ PUBLICAR
```

---

## ANTI-PATRONES A EVITAR

1. **NO** repetir correcciones ya hechas (revisar AUDIT_LOG.md)
2. **NO** bajar estándares para alcanzar convergencia
3. **NO** ignorar problemas nuevos por estar "cerca del final"
4. **NO** modificar archivos sin documentar en AUDIT_LOG.md
5. **NO** declarar versión final si hay problemas 🟡 MEDIOS pendientes

---

## REFERENCIAS

- [CIS Ubuntu Linux 24.04 LTS Benchmark](https://www.cisecurity.org/benchmark/ubuntu_linux)
- [Tailscale Security Hardening](https://tailscale.com/kb/1196/security-hardening)
- [OWASP Top 10 for Agentic Applications 2026](https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/)
- [OWASP Top 10 for LLM Applications 2025](https://genai.owasp.org/resource/owasp-top-10-for-llm-applications-2025/)
- [systemd Hardening](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#Sandboxing)

---

*Versión del protocolo: 1.0*
*Creado: 2026-02-01*
