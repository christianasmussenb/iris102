# Índice de Documentación del Proyecto

**Proyecto**: IRIS102 - Sistema de Ingesta de Archivos CSV  
**Fecha**: 17 de Octubre 2025  
**Estado**: Sprint 4 Completado, Sprint 5 Planificado

---

## 📋 Documentos de Gestión

### Reportes de Sprint

| Documento | Líneas | Descripción |
|-----------|--------|-------------|
| [RESUMEN_EJECUTIVO_SPRINT4.md](RESUMEN_EJECUTIVO_SPRINT4.md) | 400 | TL;DR del Sprint 4 con métricas clave |
| [REPORTE_FINAL_SPRINT4_ODBC.md](REPORTE_FINAL_SPRINT4_ODBC.md) | 1300 | Reporte completo del sprint con detalles |
| [REPORTE_SESION_16OCT2025.md](REPORTE_SESION_16OCT2025.md) | 800 | Sesión de trabajo anterior |

### Planes y Estrategia

| Documento | Líneas | Descripción |
|-----------|--------|-------------|
| [PLAN_MIGRACION_JDBC.md](PLAN_MIGRACION_JDBC.md) | 1200 | Roadmap detallado para Sprint 5 |
| [PLAN_ACCION_16OCT2025.md](PLAN_ACCION_16OCT2025.md) | 300 | Plan de acción anterior |

### Seguimiento

| Documento | Líneas | Descripción |
|-----------|--------|-------------|
| [avances.md](avances.md) | 350+ | Registro cronológico de avances |
| [readme.md](readme.md) | 400+ | README principal del proyecto |

---

## 🔧 Documentación Técnica

### Guías de Desarrollo

| Documento | Líneas | Descripción |
|-----------|--------|-------------|
| [BUENAS_PRACTICAS_IRIS.md](BUENAS_PRACTICAS_IRIS.md) | 4000+ | **⭐ DOCUMENTO PRINCIPAL** Guía completa de desarrollo IRIS |

**Contenido de BUENAS_PRACTICAS_IRIS.md**:
- Arquitectura de Interoperability
- Patrones de diseño
- Business Services, Processes, Operations
- Gestión de mensajes y streams
- Persistencia y bases de datos
- Debugging y troubleshooting
- Mejores prácticas de ObjectScript
- Ejemplos de código
- Performance y optimización

### Análisis de Problemas

| Documento | Líneas | Descripción |
|-----------|--------|-------------|
| [PROBLEMA_ODBC_DOCUMENTADO.md](PROBLEMA_ODBC_DOCUMENTADO.md) | 1500 | Análisis exhaustivo del problema ODBC |

**Contenido**:
- Síntomas del ERROR #6022
- 15+ configuraciones probadas
- Evidencia de la paradoja (isql funciona, IRIS falla)
- Análisis técnico profundo
- Variables de entorno y configuración
- Decisión de migrar a JDBC

### Debugging y Testing

| Documento | Líneas | Descripción |
|-----------|--------|-------------|
| [DEBUGGING_SESSION_17OCT_TARDE.md](DEBUGGING_SESSION_17OCT_TARDE.md) | 600 | Sesión de debugging del problema ODBC |
| [TESTING_SPRINT2.md](TESTING_SPRINT2.md) | 200 | Testing de sprint anterior |
| [VALIDACION_SPRINT2_FINAL.md](VALIDACION_SPRINT2_FINAL.md) | 150 | Validación final sprint 2 |

---

## 🏗️ Arquitectura del Sistema

### Componentes Principales

```
./data/IN/ → FileService → Process → Operations → ./data/OUT/
                ↓              ↓            ↓
           Event Log      Parsing    Database Insert
```

**Estado de Componentes**:
- ✅ FileService: Operacional (lee Stream completo)
- ✅ Process: Operacional (parsea desde memoria)
- ✅ Messages: Operacional (flujo completo)
- ❌ MySQL Operation: Bloqueado por ODBC
- ❌ PostgreSQL Operation: Bloqueado por ODBC

### Arquitectura Implementada en Sprint 4

**Antes (❌ Problemático)**:
```
FileService → Message(FilePath) → Process
                                    ↓
                              Read file (❌ ya movido)
```

**Después (✅ Correcto)**:
```
FileService → Message(CSVContent) → Process
   ↓                                   ↓
Read Stream                      Parse string
```

---

## 📊 Estado del Proyecto

### Completado ✅

| Componente | Estado | Descripción |
|------------|--------|-------------|
| Arquitectura Stream-to-String | ✅ 100% | FileService pasa contenido en mensaje |
| Demo.Msg.FileProcessRequest | ✅ 100% | Propiedad CSVContent agregada |
| Demo.FileService | ✅ 100% | Lee Stream completo |
| Demo.Process | ✅ 100% | Parsea desde string |
| Documentación | ✅ 100% | 8000+ líneas documentadas |
| Plan JDBC | ✅ 100% | Roadmap completo Sprint 5 |

### Bloqueado ❌

| Componente | Estado | Problema |
|------------|--------|----------|
| ODBC Connectivity | ❌ Bloqueado | ERROR #6022 irresolvible |
| Database Inserts | ❌ 0 registros | No hay conectividad |
| MySQL Operation | ❌ Bloqueado | Esperando JDBC |
| PostgreSQL Operation | ❌ Bloqueado | Esperando JDBC |

### En Planificación 📋

| Tarea | Sprint | Estado |
|-------|--------|--------|
| Verificar Java Gateway | 5 | Planificado |
| Configurar JDBC | 5 | Planificado |
| Desarrollar JDBC Operations | 5 | Planificado |
| Testing End-to-End | 5 | Planificado |
| Dockerización JDBC | 5 | Planificado |

---

## 🎯 Próximos Pasos

### Sprint 5 - Migración JDBC (3-4 días)

**Ver**: [PLAN_MIGRACION_JDBC.md](PLAN_MIGRACION_JDBC.md)

**Fases**:
1. Investigación Java Gateway (4h)
2. Configuración Java Gateway (4h)
3. Desarrollo JDBC Operations (6h)
4. Testing y validación (4h)
5. Correcciones (4h)
6. Documentación (3h)

**Total estimado**: 25 horas

---

## 📚 Cómo Usar Esta Documentación

### Para Desarrolladores Nuevos

1. **Inicio**: Leer [readme.md](readme.md)
2. **Arquitectura**: Leer [BUENAS_PRACTICAS_IRIS.md](BUENAS_PRACTICAS_IRIS.md)
3. **Estado actual**: Leer [RESUMEN_EJECUTIVO_SPRINT4.md](RESUMEN_EJECUTIVO_SPRINT4.md)
4. **Próximos pasos**: Leer [PLAN_MIGRACION_JDBC.md](PLAN_MIGRACION_JDBC.md)

### Para Troubleshooting

1. **Problema ODBC**: Ver [PROBLEMA_ODBC_DOCUMENTADO.md](PROBLEMA_ODBC_DOCUMENTADO.md)
2. **Debugging general**: Ver [BUENAS_PRACTICAS_IRIS.md](BUENAS_PRACTICAS_IRIS.md) sección "Debugging"
3. **Logs de sesiones**: Ver archivos `DEBUGGING_SESSION_*.md`

### Para Gestión del Proyecto

1. **Estado general**: Ver [RESUMEN_EJECUTIVO_SPRINT4.md](RESUMEN_EJECUTIVO_SPRINT4.md)
2. **Reportes detallados**: Ver [REPORTE_FINAL_SPRINT4_ODBC.md](REPORTE_FINAL_SPRINT4_ODBC.md)
3. **Planes futuros**: Ver [PLAN_MIGRACION_JDBC.md](PLAN_MIGRACION_JDBC.md)
4. **Historial**: Ver [avances.md](avances.md)

---

## 📈 Métricas de Documentación

### Documentos por Categoría

| Categoría | Documentos | Líneas | % |
|-----------|------------|--------|---|
| Gestión | 6 | 2500 | 25% |
| Técnica | 4 | 6000 | 60% |
| Planning | 2 | 1500 | 15% |
| **TOTAL** | **12** | **10000+** | **100%** |

### Evolución de Documentación

| Sprint | Docs Creados | Líneas Agregadas |
|--------|--------------|------------------|
| 1-3 | 4 | 1000 |
| 4 | 8 | 9000+ |

**Incremento**: 900% en Sprint 4 🚀

---

## 🔍 Búsqueda Rápida

### Por Tema

- **ODBC**: `PROBLEMA_ODBC_DOCUMENTADO.md`
- **JDBC**: `PLAN_MIGRACION_JDBC.md`
- **Arquitectura**: `BUENAS_PRACTICAS_IRIS.md`
- **FileService**: `BUENAS_PRACTICAS_IRIS.md`, `REPORTE_FINAL_SPRINT4_ODBC.md`
- **Testing**: `TESTING_SPRINT2.md`, `PLAN_MIGRACION_JDBC.md`
- **Docker**: `readme.md`, `PLAN_MIGRACION_JDBC.md`

### Por Error

- **ERROR #6022**: `PROBLEMA_ODBC_DOCUMENTADO.md`
- **Race Conditions**: `REPORTE_FINAL_SPRINT4_ODBC.md`
- **Credentials**: `REPORTE_FINAL_SPRINT4_ODBC.md`

### Por Componente

- **Demo.FileService**: `BUENAS_PRACTICAS_IRIS.md` (sección Business Services)
- **Demo.Process**: `BUENAS_PRACTICAS_IRIS.md` (sección Business Processes)
- **Demo.*.Operation**: `BUENAS_PRACTICAS_IRIS.md` (sección Business Operations)

---

## ✅ Checklist de Lectura Recomendada

### Para Iniciar Desarrollo

- [ ] Leer `readme.md` completo
- [ ] Revisar `RESUMEN_EJECUTIVO_SPRINT4.md`
- [ ] Estudiar `BUENAS_PRACTICAS_IRIS.md` (al menos primeras 1000 líneas)
- [ ] Revisar `PLAN_MIGRACION_JDBC.md` para entender próximos pasos

### Para Entender Problema ODBC

- [ ] Leer `PROBLEMA_ODBC_DOCUMENTADO.md` completo
- [ ] Revisar sección ODBC en `REPORTE_FINAL_SPRINT4_ODBC.md`
- [ ] Ver configuraciones probadas

### Para Implementar JDBC

- [ ] Leer `PLAN_MIGRACION_JDBC.md` completo
- [ ] Revisar sección JDBC en `BUENAS_PRACTICAS_IRIS.md`
- [ ] Estudiar ejemplos de código propuestos

---

**Actualizado**: 17 de Octubre 2025  
**Mantenedor**: GitHub Copilot AI Assistant  
**Próxima revisión**: Inicio Sprint 5
