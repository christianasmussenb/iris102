# Plan de Continuación - Proyecto IRIS102

## Estado Actual del Proyecto

### ✅ Completado (29% del proyecto)
- **Sprint 1**: Infraestructura Docker completa
- **Sprint 2**: Clases base ObjectScript implementadas

### 🔄 Siguiente Paso Inmediato: Validación Sprint 2

**CRÍTICO**: Antes de continuar al Sprint 3, debemos verificar que las clases implementadas funcionan correctamente.

## Plan de Acción Recomendado

### FASE 1: Validación y Testing (0.5-1 día)

#### 1.1 Inicializar Infraestructura
```bash
cd /Users/cab/VSCODE/iris102

# Preparar variables de entorno
cp env.example .env

# Iniciar servicios
docker compose up -d

# Verificar estado
docker compose ps
docker compose logs iris
```

#### 1.2 Testing de Clases Base
```bash
# Acceder a IRIS
docker exec -it iris102 iris session iris -U DEMO

# Ejecutar testing según TESTING_SPRINT2.md
```

**Criterios de aceptación Sprint 2**:
- [ ] Todas las clases se compilan sin errores
- [ ] Production se carga correctamente
- [ ] Utilidades de logging funcionan
- [ ] Mensajes se crean y validan
- [ ] Conexiones DB configuradas

### FASE 2: Sprint 3 - Business Service Completo (2-3 días)

Una vez validado Sprint 2, implementar:

#### 3.1 Demo.FileService Completo
**Objetivo**: Detectar, procesar y mover archivos CSV automáticamente

**Funcionalidades a implementar**:
- ✅ Configuración EnsLib.File.InboundAdapter (ya hecho)
- 🔨 Detección automática de archivos `file*.csv`
- 🔨 Cálculo de hash SHA256 para duplicados
- 🔨 Validación de formato CSV
- 🔨 Creación de FileProcessRequest
- 🔨 Envío a Demo.Process
- 🔨 Manejo de respuesta
- 🔨 Movimiento a /data/OUT/ con renombrado
- 🔨 Logging completo del proceso

#### 3.2 Integración con Utilidades Existentes
- Usar Demo.Util.Logger para hash y validación
- Implementar detección de duplicados
- Logging en Event Log y archivos diarios

#### 3.3 Testing End-to-End Básico
```bash
# Test del flujo completo de detección
cp data/samples/file1.csv data/IN/
# Verificar que se procesa automáticamente
# Verificar archivo en data/OUT/
# Verificar logs en data/LOG/
```

### FASE 3: Sprint 4 - Business Process (3-4 días)

#### 4.1 Demo.Process - Parser CSV Completo
- Parser CSV robusto con manejo de errores
- Validación de tipos de datos
- Creación de Demo.Msg.CSVRecord objects
- Coordinación de envío a operaciones DB

#### 4.2 Lógica de Orquestación
- Envío paralelo a MySQL y PostgreSQL
- Manejo de respuestas parciales
- Cálculo de métricas (total, ok, failed)
- Determinación de status final (ok/partial/error)

### FASE 4: Sprint 5 - Operations Database (3-4 días)

#### 5.1 Demo.MySQL.Operation Completo
- Configuración JDBC para MySQL
- INSERT/UPSERT parametrizados
- Sistema de reintentos con backoff

#### 5.2 Demo.Postgres.Operation Completo
- Configuración JDBC para PostgreSQL
- Manejo de SSL para conexiones externas
- Sistema de reintentos independiente

### FASE 5: Sprints 6-7 - Integración y Documentación (2-3 días)

## Decisiones Arquitectónicas Pendientes

### 1. **Parser CSV**
- **Opción A**: Usar %CSVReader nativo de IRIS
- **Opción B**: Implementar parser custom con mejor control de errores
- **Recomendación**: Opción A para simplicidad, Opción B si necesitamos más control

### 2. **Manejo de Duplicados**
- **Actual**: Global simple ^Demo.ProcessedFiles
- **Mejora**: Tabla persistente con índices
- **Recomendación**: Mantener global para MVP, migrar a tabla después

### 3. **Estrategia de Reintentos**
- **MySQL falla**: ¿Reintenta N veces o marca como failed inmediatamente?
- **PostgreSQL falla**: ¿Procede con MySQL o cancela todo?
- **Recomendación**: Reintentos independientes, status partial si uno falla

### 4. **Configuración de PostgreSQL Externo**
- **Necesitamos**: Configurar una instancia externa real
- **Alternativa**: Usar PostgreSQL local hasta tener externa
- **Recomendación**: PostgreSQL local para desarrollo, externa para demo final

## Próximas Acciones Inmediatas

### HOY (14 Oct 2025)
1. **Validar Sprint 2**: Ejecutar TESTING_SPRINT2.md
2. **Corregir errores** encontrados en compilación/testing
3. **Planificar Sprint 3** detalladamente

### MAÑANA (15 Oct 2025)
1. **Implementar Demo.FileService completo**
2. **Testing de detección de archivos**
3. **Integración con utilidades existentes**

### ESTA SEMANA
1. **Completar Sprint 3** (Business Service)
2. **Iniciar Sprint 4** (Business Process)
3. **Testing continuo** de componentes

## Riesgos y Mitigaciones

### 🚨 **Riesgos Identificados**
1. **Compilación de clases**: Posibles errores de sintaxis ObjectScript
2. **Configuración IRIS**: Problemas con Interoperability setup
3. **Conexiones DB**: Configuración JDBC puede fallar
4. **Performance**: Archivos grandes pueden causar timeouts

### 🛡️ **Mitigaciones**
1. **Testing incremental**: Validar cada clase por separado
2. **Logging detallado**: Para troubleshooting rápido
3. **Configuración flexible**: Variables de entorno para ajustes
4. **Implementación por fases**: Un componente a la vez

## Métricas de Éxito Sprint 3

### Criterios de Aceptación
- [ ] Archivo CSV copiado a /data/IN/ se detecta en <10 segundos
- [ ] Hash SHA256 se calcula correctamente
- [ ] Archivos duplicados se detectan y marcan como "duplicate"
- [ ] Archivo se mueve a /data/OUT/ con naming correcto
- [ ] Logs se escriben en Event Log y archivo diario
- [ ] No hay errores de compilación o runtime

### Test Case Específico
```bash
# Test 1: Procesamiento normal
cp data/samples/file1.csv data/IN/test1.csv
# Esperar: test1__YYYYMMDD_HHMMSS__ok.csv en data/OUT/

# Test 2: Duplicado
cp data/samples/file1.csv data/IN/test2.csv
# Esperar: test2__YYYYMMDD_HHMMSS__duplicate.csv en data/OUT/

# Test 3: Archivo inválido
echo "invalid content" > data/IN/invalid.csv
# Esperar: invalid__YYYYMMDD_HHMMSS__error.csv en data/OUT/
```

---

**Conclusión**: El proyecto tiene una base sólida. El próximo paso crítico es validar Sprint 2 y luego implementar un Business Service funcional que demuestre el flujo end-to-end básico.