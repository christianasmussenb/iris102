# COPILOT_TASKS.md - Criterios de Aceptación y Lista de Tareas

## Criterios de Aceptación Principal

### 1. Procesamiento Automático de Archivos ✅ Infraestructura Lista
**Criterio**: Al copiar `file1.csv` a `./data/IN/`, el Service lo detecta, procesa y lo mueve a `./data/OUT/` renombrado con timestamp y status.

**Validación**:
- [ ] Archivo detectado automáticamente en máximo 10 segundos
- [ ] Archivo movido a OUT con formato: `<nombre>__YYYYMMDD_HHMMSS__<status>.csv`
- [ ] Status correcto: `ok`, `partial`, `error`, `duplicate`
- [ ] Archivo original removido de IN

### 2. Inserción en Bases de Datos ⏳ Pendiente Sprint 5
**Criterio**: Registros insertados en **MySQL** y **PostgreSQL** (si Postgres falla, status `partial` y se loggea).

**Validación**:
- [ ] Datos insertados correctamente en MySQL local
- [ ] Datos insertados correctamente en PostgreSQL externo
- [ ] Manejo de fallas parciales (MySQL ok, PostgreSQL fail → status `partial`)
- [ ] Prevención de SQL injection con queries parametrizadas
- [ ] Upsert por clave natural (external_id, occurred_at)

### 3. Sistema de Logging ⏳ Pendiente Sprint 2
**Criterio**: Logs creados en `./data/LOG/ingest_YYYYMMDD.log` con líneas START/END y métricas.

**Validación**:
- [ ] Archivo de log diario creado automáticamente
- [ ] Línea START con: timestamp, filename, size, hash
- [ ] Línea END con: timestamp, filename, status, métricas de procesamiento
- [ ] Event Log de IRIS con eventos de proceso
- [ ] Logs de errores detallados con stack traces

### 4. Tolerancia a Fallas y Duplicados ⏳ Pendiente Sprint 3
**Criterio**: Reintentos implementados en las Operations y sin duplicados si el mismo archivo entra dos veces.

**Validación**:
- [ ] Detección de duplicados por hash SHA256
- [ ] Archivo duplicado movido a OUT con status `duplicate`
- [ ] Reintentos con backoff exponencial (3 intentos: 0.5s, 2s, 5s)
- [ ] Fallas transitorias manejadas correctamente
- [ ] Recuperación automática después de fallos de red/DB

### 5. Configuración por Variables de Entorno ✅ Completado
**Criterio**: Toda la configuración sensible viene desde `.env`.

**Validación**:
- [x] No hay passwords hardcodeados en el código
- [x] Todas las conexiones DB configurables por ENV
- [x] Rutas de archivos configurables
- [x] Parámetros de retry y timeouts configurables
- [x] Template `.env.example` documentado

### 6. Despliegue con Docker Compose ✅ Completado
**Criterio**: `docker-compose up` levanta IRIS + MySQL; con Postgres externo configurable por ENV.

**Validación**:
- [x] IRIS Community ejecutándose y accesible
- [x] MySQL local inicializado con tablas
- [x] Adminer funcional para gestión de MySQL
- [x] PostgreSQL local opcional para testing
- [x] Volúmenes persistentes configurados
- [x] Red de contenedores configurada correctamente

### 7. Documentación y Usabilidad ✅ Completado
**Criterio**: README con pasos: `docker-compose up`, configurar connections en IRIS si aplica, prueba con el sample, verificación en MySQL/Postgres, dónde ver logs/eventos.

**Validación**:
- [x] README con instrucciones paso a paso
- [x] Sección de troubleshooting
- [x] Ejemplos de uso con archivos CSV
- [x] Comandos para verificar funcionamiento
- [x] Documentación de variables de entorno

## Lista de Tareas por Sprint

### Sprint 1: Infraestructura Base ✅ COMPLETADO
- [x] Estructura de carpetas completa
- [x] Docker Compose con todos los servicios
- [x] Scripts SQL de inicialización
- [x] Variables de entorno y configuración
- [x] Dockerfile de IRIS personalizado
- [x] Script de inicialización automática
- [x] Clase Installer.cls
- [x] Archivos CSV de muestra
- [x] README completo

### Sprint 2: Clases Base de InterSystems IRIS ✅ COMPLETADO
- [x] Demo.Production.cls - Configuración de la Production
- [x] Demo.Msg.Record.cls - Mensajes Request/Response  
- [x] Demo.Util.Logger.cls - Utilidades de logging y hash
- [x] Configuración de adaptadores EnsLib
- [x] Compilación y carga automática

### Sprint 3: Business Service - Detección de Archivos ⏳ PENDIENTE
- [ ] Demo.FileService.cls con EnsLib.File.InboundAdapter
- [ ] Configuración de FileSpec="file*.csv"
- [ ] Cálculo de hash SHA256 para duplicados
- [ ] Movimiento y renombrado de archivos
- [ ] Logging de eventos de procesamiento

### Sprint 4: Business Process - Parser CSV ⏳ PENDIENTE  
- [ ] Demo.BPL.Process.bpl o Demo.Process.cls
- [ ] Parser CSV robusto con manejo de cabeceras
- [ ] Validación de tipos de datos
- [ ] Coordinación de múltiples operaciones
- [ ] Manejo de respuestas y errores

### Sprint 5: Business Operations - Conectores DB ⏳ PENDIENTE
- [ ] Demo.MySQL.Operation.cls 
- [ ] Demo.Postgres.Operation.cls
- [ ] Configuración de DSN/JDBC
- [ ] Queries parametrizadas y upserts
- [ ] Sistema de reintentos con backoff

### Sprint 6: Integración y Testing ⏳ PENDIENTE
- [ ] Flujo end-to-end completo
- [ ] Pruebas con archivos CSV reales
- [ ] Pruebas de tolerancia a fallas
- [ ] Configuración de PostgreSQL externo
- [ ] Performance testing

### Sprint 7: Documentación y Refinamiento ⏳ PENDIENTE
- [ ] Documentación técnica completa
- [ ] Guías de troubleshooting detalladas
- [ ] Optimizaciones de performance
- [ ] Criterios de aceptación verificados
- [ ] Release notes y changelog

## Tests de Aceptación Automatizados

### Test 1: Procesamiento Básico
```bash
# 1. Copiar archivo de muestra
cp data/samples/file1.csv data/IN/file_test1.csv

# 2. Esperar procesamiento (max 30 segundos)
timeout 30 bash -c 'while [[ -f data/IN/file_test1.csv ]]; do sleep 1; done'

# 3. Verificar archivo en OUT
ls data/OUT/file_test1__*__*.csv

# 4. Verificar datos en MySQL
docker exec iris102-mysql mysql -udemo -pdemo_pass demo -e "SELECT COUNT(*) FROM records WHERE source_file LIKE '%file_test1%';"

# 5. Verificar logs
grep "file_test1" data/LOG/ingest_$(date +%Y%m%d).log
```

### Test 2: Detección de Duplicados  
```bash
# 1. Procesar archivo original
cp data/samples/file1.csv data/IN/file_dup_test.csv
sleep 10

# 2. Intentar procesar el mismo archivo
cp data/samples/file1.csv data/IN/file_dup_test2.csv  
sleep 10

# 3. Verificar que el segundo tiene status duplicate
ls data/OUT/file_dup_test2__*__duplicate.csv
```

### Test 3: Manejo de Errores
```bash
# 1. Crear archivo CSV con formato inválido
echo "invalid,csv,data" > data/IN/invalid_test.csv
sleep 10

# 2. Verificar que se marca como error
ls data/OUT/invalid_test__*__error.csv

# 3. Verificar logs de error
grep "ERROR" data/LOG/ingest_$(date +%Y%m%d).log
```

## Métricas de Calidad

- **Cobertura de Código**: >80% en clases principales
- **Performance**: Procesar 1000 registros en <30 segundos  
- **Disponibilidad**: Sistema recuperable en <2 minutos tras fallo
- **Logs**: Trazabilidad completa de cada archivo procesado
- **Seguridad**: No exposición de credenciales en logs o código

## Estado de Progreso

- ✅ **Completado**: 2/7 Sprints (29%)
- 🔄 **Siguiente**: Sprint 3 - Business Service (detección de archivos)
- ⏳ **Pendiente**: Sprints 4-7
- 🎯 **Objetivo**: Completar todos los criterios de aceptación

### Resumen de Avances

**Sprint 1 ✅**: Infraestructura Docker completa con IRIS, MySQL, PostgreSQL
**Sprint 2 ✅**: Clases base ObjectScript, mensajes, utilidades, Production configurada
**Sprint 3 ⏳**: Implementación completa de Demo.FileService
**Sprint 4 ⏳**: Parser CSV y orquestación en Demo.Process
**Sprint 5 ⏳**: Operaciones de base de datos MySQL y PostgreSQL
**Sprint 6 ⏳**: Integración end-to-end y testing
**Sprint 7 ⏳**: Documentación final y refinamiento

---

**Última actualización**: 14 de octubre de 2025  
**Próxima revisión**: Completar Sprint 2