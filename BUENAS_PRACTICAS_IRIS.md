# Buenas Prácticas para Desarrollo en InterSystems IRIS

## Guía de Desarrollo Basada en Experiencia del Proyecto iris102

**Fecha:** 17 de octubre de 2025  
**Proyecto Base:** iris102 - Integración CSV a MySQL/PostgreSQL vía ODBC  
**Autor:** Documentación basada en experiencia real de desarrollo

---

## 📋 Índice

1. [Estructura de Proyecto](#estructura-de-proyecto)
2. [Gestión de Código Fuente](#gestión-de-código-fuente)
3. [Compilación y Despliegue](#compilación-y-despliegue)
4. [Conectividad de Bases de Datos](#conectividad-de-bases-de-datos)
5. [Arquitectura de Interoperability](#arquitectura-de-interoperability)
6. [Debugging y Troubleshooting](#debugging-y-troubleshooting)
7. [Docker y Entorno de Desarrollo](#docker-y-entorno-de-desarrollo)
8. [Testing y Validación](#testing-y-validación)
9. [Errores Comunes y Soluciones](#errores-comunes-y-soluciones)

---

## 1. Estructura de Proyecto

### 1.1 Organización Recomendada de Directorios

```
proyecto-iris/
├── iris/
│   ├── Dockerfile                    # Construcción del contenedor IRIS
│   ├── Installer.cls                 # Clase de instalación/setup
│   ├── iris.script                   # Script de inicialización
│   ├── src/
│   │   └── <namespace>/              # Código fuente por namespace
│   │       └── prod/                 # Clases de producción
│   │           ├── *.cls             # Clases de negocio
│   │           └── Msg/              # Clases de mensajes
│   └── odbc/                         # Configuración ODBC si aplica
│       ├── odbc.ini
│       └── odbcinst.ini
├── data/
│   ├── IN/                           # Entrada de datos
│   ├── OUT/                          # Salida procesada
│   ├── LOG/                          # Logs de procesamiento
│   └── WIP/                          # Work in progress
├── sql/                              # Scripts SQL externos
│   ├── mysql_init.sql
│   └── postgres_init.sql
├── docker-compose.yml                # Orquestación de servicios
└── README.md                         # Documentación principal
```

### 1.2 Convenciones de Nombres

**Packages (Namespaces):**
- Usar PascalCase: `Demo`, `MyApp`, `CompanyName`
- Evitar guiones bajos o caracteres especiales

**Clases:**
- Business Services: `<Nombre>Service` → `Demo.FileService`
- Business Processes: `<Nombre>Process` → `Demo.Process`
- Business Operations: `<Nombre>Operation` → `Demo.MySQL.Operation`
- Messages: `Demo.Msg.<TipoMensaje>` → `Demo.Msg.FileProcessRequest`

**Properties:**
- PascalCase: `TargetConfigName`, `FilePath`, `CSVContent`
- Boolean: Usar `Is` o `Has` como prefijo → `IsValid`, `HasHeader`

---

## 2. Gestión de Código Fuente

### 2.1 Flujo de Trabajo Recomendado

#### ✅ OPCIÓN A: Desarrollo en IDE → Load → Compile (RECOMENDADO)

```bash
# 1. Editar archivos .cls en tu IDE favorito (VS Code)
# 2. Copiar archivos al contenedor (si no hay volumen compartido)
docker cp iris/src/demo/prod/MiClase.cls iris102:/opt/irisapp/iris/src/demo/prod/

# 3. Conectarse a IRIS
docker exec -it iris102 iris session IRIS -U DEMO

# 4. Cargar y compilar desde terminal IRIS
Do $system.OBJ.Load("/opt/irisapp/iris/src/demo/prod/MiClase.cls", "ck")

# 5. O compilar paquete completo
Do $system.OBJ.CompilePackage("Demo", "ckr")
```

#### ✅ OPCIÓN B: Usar Volúmenes Docker (MÁS SIMPLE)

```yaml
# En docker-compose.yml
services:
  iris:
    volumes:
      - ./iris/src:/opt/irisapp/iris/src:ro  # Read-only para seguridad
```

**Ventajas:**
- Cambios en archivos locales se reflejan inmediatamente en contenedor
- No necesitas copiar archivos manualmente
- Facilita el desarrollo iterativo

### 2.2 Comandos de Compilación

```objectscript
// Compilar una sola clase
Do $system.OBJ.Compile("Demo.MiClase", "ck")

// Compilar con recompilación de dependencias
Do $system.OBJ.Compile("Demo.MiClase", "ckr")

// Compilar paquete completo
Do $system.OBJ.CompilePackage("Demo", "ckr")

// Cargar desde archivo
Do $system.OBJ.Load("/path/to/file.cls", "ck")

// Verificar errores de compilación
Write $System.Status.GetErrorText($system.OBJ.Compile("Demo.MiClase", "ck"))
```

**Flags importantes:**
- `c` = Compile
- `k` = Keep source code loaded
- `r` = Recursive (recompilar dependencias)
- `d` = Display errors
- `u` = Update (no recompilar si no hay cambios)

### 2.3 ⚠️ Evitar Heredocs Complejos en Terminal

**❌ NO FUNCIONA BIEN:**
```bash
# Heredocs con ObjectScript pueden fallar
docker exec iris102 iris session IRIS -U DEMO << 'EOF'
Do $system.OBJ.Compile("Demo.Class", "ck")
Halt
EOF
```

**✅ USAR ALTERNATIVAS:**
```bash
# Opción 1: Echo con pipe
docker exec iris102 bash -c "echo 'Do \$system.OBJ.Compile(\"Demo.Class\", \"ck\")' | iris session IRIS -U DEMO"

# Opción 2: Crear script temporal
echo 'Do $system.OBJ.CompilePackage("Demo", "ckr")' > /tmp/compile.txt
docker cp /tmp/compile.txt iris102:/tmp/
docker exec iris102 bash -c "cat /tmp/compile.txt | iris session IRIS -U DEMO"

# Opción 3: Script .sh con comandos individuales
docker exec iris102 iris session IRIS -U DEMO "Do \$system.OBJ.CompilePackage(\"Demo\", \"ckr\")"
```

---

## 3. Compilación y Despliegue

### 3.1 Secuencia de Inicio de Production

```objectscript
// 1. Habilitar Interoperability en namespace (solo primera vez)
Do ##class(%EnsembleMgr).EnableNamespace("DEMO", 1)

// 2. Compilar todas las clases
Do $system.OBJ.CompilePackage("Demo", "ckr")

// 3. Iniciar Production
Do ##class(Ens.Director).StartProduction("Demo.Production")

// 4. Verificar estado
Write ##class(Ens.Director).IsProductionRunning()

// 5. Actualizar Production (después de cambios en XData)
Do ##class(Ens.Director).UpdateProduction()

// 6. Detener Production
Do ##class(Ens.Director).StopProduction()
```

### 3.2 Gestión de Credenciales

```objectscript
// Crear credenciales
Do ##class(Ens.Config.Credentials).SetCredential("MySQL-Demo-Credentials", "demo", "demo_pass", 1)

// Verificar credenciales
Set creds = ##class(Ens.Config.Credentials).%OpenId("MySQL-Demo-Credentials")
Write creds.Username

// Nota: El password no es recuperable directamente (encriptado)
```

### 3.3 Actualizar Configuración de Production

**Después de modificar XData en Production.cls:**

1. Compilar la clase
2. **Ejecutar UpdateProduction()** - ¡CRÍTICO!
3. Verificar en Portal que los cambios se aplicaron

```objectscript
// Secuencia completa
Do $system.OBJ.Compile("Demo.Production", "ck")
Do ##class(Ens.Director).UpdateProduction()
```

**⚠️ IMPORTANTE:** UpdateProduction() NO reinicia componentes automáticamente. Si cambias Settings críticos, es mejor Stop → Start.

---

## 4. Conectividad de Bases de Datos

### 4.1 ODBC vs JDBC vs SQL Gateway

#### 🔍 Conceptos Importantes (LECCIÓN CLAVE)

| Tecnología | Propósito | Cuándo Usar |
|------------|-----------|-------------|
| **ODBC DSN** | Conectar IRIS a bases de datos externas vía ODBC | SQL queries desde Business Operations |
| **JDBC** | Conectar IRIS a bases de datos externas vía Java | Cuando ODBC no está disponible o prefieres Java |
| **SQL Gateway Connections** | Configurar conexiones SQL persistentes | Queries complejos, múltiples tablas, joins |
| **External Language Servers** | Ejecutar código Java/.NET desde ObjectScript | Integración con librerías externas, NO para SQL |

**⚠️ ERROR COMÚN:** 
`Config.Gateways` crea **External Language Servers** (Java/.NET), NO conexiones SQL Gateway. Para SQL, usar ODBC DSN o crear SQL Gateway Connections desde Portal.

### 4.2 Configuración ODBC en Docker

**Archivo `/etc/odbc.ini`:**
```ini
[MySQL-Demo]
Driver=MariaDB ODBC 3.1 Driver
Server=mysql                    # Nombre del servicio en docker-compose
Port=3306
Database=demo
USER=demo
PASSWORD=demo_pass
Option=3

[PostgreSQL-Demo]
Driver=PostgreSQL Unicode
Servername=postgres             # Nombre del servicio en docker-compose
Port=5432
Database=demo
UserName=demo
Password=demo_pass
SSLmode=disable
```

**Archivo `/etc/odbcinst.ini`:**
```ini
[MariaDB ODBC 3.1 Driver]
Description=MariaDB Connector/ODBC v.3.1
Driver=/usr/lib/libmaodbc.so    # ARM64: /usr/lib/, x86: /usr/lib64/

[PostgreSQL Unicode]
Description=PostgreSQL ODBC driver (Unicode version)
Driver=/usr/lib/psqlodbcw.so
```

### 4.3 Verificación de Conectividad ODBC

```bash
# 1. Verificar drivers instalados
docker exec iris102 odbcinst -q -d

# 2. Verificar DSN configurados
docker exec iris102 odbcinst -q -s

# 3. Test de conexión con isql
docker exec iris102 isql MySQL-Demo demo demo_pass -v
docker exec iris102 isql PostgreSQL-Demo demo demo_pass -v

# 4. Query de prueba
docker exec iris102 isql MySQL-Demo demo demo_pass -v -c "SELECT 1;"
```

### 4.4 Uso de EnsLib.SQL.OutboundAdapter

```objectscript
Class Demo.MySQL.Operation Extends Ens.BusinessOperation
{
    Parameter ADAPTER = "EnsLib.SQL.OutboundAdapter";
    
    Property Adapter As EnsLib.SQL.OutboundAdapter;
    
    Method OnMessage(pRequest As Demo.Msg.DatabaseInsertRequest, 
                     Output pResponse As Demo.Msg.DatabaseInsertResponse) As %Status
    {
        // Crear statement
        Set stmt = ..Adapter.CreateStatement()
        
        // Preparar SQL con parámetros
        Set sql = "INSERT INTO csv_records (csv_id, name, age, city) VALUES (?, ?, ?, ?)"
        Set status = stmt.%Execute(csvId, name, age, city)
        
        // Verificar resultado
        If $$$ISERR(status) {
            // Manejar error
        }
        
        Return $$$OK
    }
}
```

**Settings en Production.cls:**
```xml
<Item Name="MySQLOperation" ClassName="Demo.MySQL.Operation">
    <Setting Target="Adapter" Name="DSN">MySQL-Demo</Setting>
    <Setting Target="Adapter" Name="Credentials">MySQL-Demo-Credentials</Setting>
</Item>
```

---

## 5. Arquitectura de Interoperability

### 5.1 Flujo de Mensajes

```
[Business Service] → [Business Process] → [Business Operation(s)]
       ↓                     ↓                        ↓
   Detecta evento      Orquesta lógica         Ejecuta acción
   (archivos, HTTP)    (transforma, decide)    (DB, API, file)
```

### 5.2 🔴 LECCIÓN CRÍTICA: FileService y Streams

#### ❌ ARQUITECTURA INCORRECTA (NO HACER)

```objectscript
// En FileService.OnProcessInput()
Method OnProcessInput(pInput As %FileCharacterStream, pOutput) As %Status
{
    Set filePath = pInput.Filename  // ❌ Solo guardamos el path
    
    Set request.FilePath = filePath  // ❌ Enviamos path en mensaje
    Set status = ..SendRequestSync("FileProcessor", request, .response)
    
    Return $$$OK
    // ⚠️ El adapter MUEVE/ELIMINA el archivo cuando este método termina
}

// En Process
Method OnRequest(pRequest As FileProcessRequest) As %Status
{
    Set filePath = pRequest.FilePath
    Set stream = ##class(%FileCharacterStream).%New()
    Set stream.Filename = filePath  // ❌ ARCHIVO YA NO EXISTE
    
    // ❌ El archivo fue movido/eliminado por el adapter
    // ❌ El Process corre asíncronamente, el archivo ya se fue
}
```

**PROBLEMA:** `EnsLib.File.InboundAdapter` controla el ciclo de vida del archivo. Cuando `OnProcessInput()` retorna, el adapter puede mover, archivar o eliminar el archivo según su configuración. El Business Process corre asíncronamente y para cuando intenta leer el archivo, ya no existe.

#### ✅ ARQUITECTURA CORRECTA (HACER)

```objectscript
// En FileService.OnProcessInput()
Method OnProcessInput(pInput As %FileCharacterStream, pOutput) As %Status
{
    // ✅ LEER CONTENIDO COMPLETO DEL STREAM
    Set csvContent = ""
    Do pInput.Rewind()
    While 'pInput.AtEnd {
        Set csvContent = csvContent _ pInput.Read(32000)
    }
    
    // ✅ PASAR CONTENIDO EN MENSAJE, NO PATH
    Set request.CSVContent = csvContent
    Set request.FileName = ##class(%File).GetFilename(pInput.Filename)
    
    Set status = ..SendRequestSync("FileProcessor", request, .response)
    Return $$$OK
}

// En Process
Method OnRequest(pRequest As FileProcessRequest) As %Status
{
    // ✅ Trabajar con contenido en memoria
    Set csvContent = pRequest.CSVContent
    
    // ✅ Parsear desde string, no desde archivo
    Do ..ParseCSVFromString(csvContent, .records)
}
```

**Message Class:**
```objectscript
Class Demo.Msg.FileProcessRequest Extends Ens.Request
{
    // ✅ Propiedad para contenido completo
    Property CSVContent As %String(MAXLEN = "");
    
    // Opcional: mantener FilePath para logging
    Property FilePath As %String(MAXLEN = 500);
    
    Property FileName As %String(MAXLEN = 255) [ Required ];
}
```

### 5.3 Configuración de File Adapter

```xml
<!-- En Production.cls -->
<Item Name="FileService" ClassName="Demo.FileService">
    <Setting Target="Adapter" Name="FilePath">/data/IN</Setting>
    <Setting Target="Adapter" Name="FileSpec">*.csv</Setting>
    <Setting Target="Adapter" Name="DeleteFromServer">0</Setting>  <!-- No borrar -->
    <Setting Target="Adapter" Name="ArchivePath">/data/OUT</Setting>  <!-- Archivar -->
    <Setting Target="Adapter" Name="WorkPath">/data/WIP</Setting>  <!-- Temporal -->
</Item>
```

**Opciones importantes:**
- `DeleteFromServer=0`: No eliminar después de procesar
- `DeleteFromServer=1`: Eliminar después de procesar
- `ArchivePath=/data/OUT`: Mover archivo procesado aquí
- `WorkPath=/data/WIP`: Usar como carpeta temporal durante procesamiento

### 5.4 SendRequestSync vs SendRequestAsync

```objectscript
// Síncrono - espera respuesta
Set status = ..SendRequestSync("TargetOperation", request, .response, 300)
// timeout en segundos ^

// Asíncrono - no espera respuesta
Set status = ..SendRequestAsync("TargetOperation", request)
```

**Cuándo usar cada uno:**
- **Sync:** Cuando necesitas la respuesta para continuar (ej: validaciones, resultados)
- **Async:** Cuando solo necesitas "fire and forget" (ej: logging, notificaciones)

---

## 6. Debugging y Troubleshooting

### 6.1 Herramientas Esenciales en Portal

#### Visual Trace (★★★★★ IMPRESCINDIBLE)

**Ubicación:** `Interoperability > Configure > Production > Messages > Visual Trace`

**Qué muestra:**
- Flujo completo de mensajes
- Request → Process → Operations
- Tiempos de procesamiento
- Errores en cada paso

**Cómo usar:**
1. Hacer clic en un Session ID del Message Viewer
2. Ver árbol de mensajes
3. Identificar dónde se detiene el flujo
4. Hacer clic en cada mensaje para ver contenido

**Ejemplo de análisis:**
```
✅ FileService → FileProcessor (Request)
✅ FileProcessor → FileService (Response)
❌ NO hay mensajes FileProcessor → MySQLOperation
```
**Conclusión:** El Process no está enviando mensajes a las Operations.

#### Message Viewer

**Qué muestra:**
- Lista de todos los mensajes
- Session ID (agrupa mensajes relacionados)
- Timestamps, Source, Target
- Status (OK, Error, Suspended)

**Filtros útiles:**
- Por componente (ej: solo MySQLOperation)
- Por tipo de mensaje
- Por rango de fechas
- Por status (errores solamente)

### 6.2 Logging Estratégico

```objectscript
// Event Log - visible en Portal
Do ##class(Ens.Util.Log).LogInfo("MiClase", "Procesando archivo: " _ fileName)
Do ##class(Ens.Util.Log).LogError("MiClase", "Error: " _ errorMsg)

// O usando macro (requiere import de Ensemble)
$$$LOGINFO("Procesando archivo: " _ fileName)
$$$LOGERROR("Error al procesar: " _ errorMsg)

// File Log - para debug detallado
Set file = ##class(%Stream.FileCharacter).%New()
Set file.Filename = "/data/LOG/debug.log"
Do file.WriteLine($ZDateTime($Horolog, 3) _ " - " _ mensaje)
Do file.%Save()
```

**Estrategia recomendada:**
- Event Log: Eventos importantes (inicio, fin, errores)
- File Log: Debug detallado (valores de variables, flujo)
- NO hacer logging excesivo en producción (afecta performance)

### 6.3 Verificación de Conectividad ODBC desde ObjectScript

```objectscript
// Método de prueba en Operation
Method TestConnection() As %Status
{
    Try {
        Set stmt = ..Adapter.CreateStatement()
        Set status = stmt.%Execute("SELECT 1")
        
        If $$$ISERR(status) {
            Write "Error: ", $System.Status.GetErrorText(status), !
            Return status
        }
        
        Write "Connection OK", !
        Return $$$OK
        
    } Catch ex {
        Write "Exception: ", ex.DisplayString(), !
        Return ex.AsStatus()
    }
}

// Llamar desde terminal
Do ##class(Demo.MySQL.Operation).TestConnection()
```

### 6.4 Queries de Diagnóstico

```sql
-- Ver configuración de Production
SELECT * FROM Ens_Config.Item WHERE Production = 'Demo.Production'

-- Ver mensajes recientes
SELECT TOP 100 TimeCreated, SessionId, SourceConfigName, TargetConfigName, Type
FROM Ens.MessageHeader
ORDER BY TimeCreated DESC

-- Ver errores
SELECT TimeCreated, SessionId, SourceConfigName, ErrorStatus
FROM Ens.MessageHeader
WHERE ErrorStatus IS NOT NULL
ORDER BY TimeCreated DESC

-- Ver performance (mensajes por componente)
SELECT SourceConfigName, COUNT(*) as MessageCount
FROM Ens.MessageHeader
GROUP BY SourceConfigName
ORDER BY MessageCount DESC
```

---

## 7. Docker y Entorno de Desarrollo

### 7.1 docker-compose.yml Recomendado

```yaml
version: '3.8'

services:
  iris:
    build:
      context: ./iris
      dockerfile: Dockerfile
    container_name: iris102
    ports:
      - "52773:52773"  # Portal Web
      - "1972:1972"    # SuperServer
    volumes:
      - ./iris/src:/opt/irisapp/iris/src:ro  # Código fuente
      - ./data:/data                          # Datos persistentes
      - iris-data:/usr/irissys/mgr           # Datos IRIS
    environment:
      - IRIS_USERNAME=_SYSTEM
      - IRIS_PASSWORD=123
      - IRIS_NAMESPACE=DEMO
    healthcheck:
      test: ["CMD", "iris", "session", "iris", "-U", "%SYS", "##class(%SYSTEM.Process).CurrentDirectory()"]
      interval: 30s
      timeout: 10s
      retries: 3
    depends_on:
      mysql:
        condition: service_healthy
      postgres:
        condition: service_healthy

  mysql:
    image: mysql:8.0
    container_name: iris102-mysql
    ports:
      - "3306:3306"
    environment:
      MYSQL_ROOT_PASSWORD: root_pass
      MYSQL_DATABASE: demo
      MYSQL_USER: demo
      MYSQL_PASSWORD: demo_pass
    volumes:
      - mysql-data:/var/lib/mysql
      - ./sql/mysql_init.sql:/docker-entrypoint-initdb.d/init.sql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5

  postgres:
    image: postgres:15
    container_name: iris102-postgres
    ports:
      - "5432:5432"
    environment:
      POSTGRES_DB: demo
      POSTGRES_USER: demo
      POSTGRES_PASSWORD: demo_pass
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./sql/postgres_init.sql:/docker-entrypoint-initdb.d/init.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U demo"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  iris-data:
  mysql-data:
  postgres-data:
```

### 7.2 Dockerfile para IRIS (ARM64 + ODBC)

```dockerfile
FROM intersystemsdc/iris-community:latest-em

# Instalar ODBC drivers (ARM64)
USER root
RUN apt-get update && apt-get install -y \
    unixodbc \
    unixodbc-dev \
    odbc-mariadb \
    odbc-postgresql \
    && rm -rf /var/lib/apt/lists/*

# Copiar configuración ODBC
COPY odbc/odbc.ini /etc/odbc.ini
COPY odbc/odbcinst.ini /etc/odbcinst.ini

# Crear directorios de datos
RUN mkdir -p /data/IN /data/OUT /data/LOG /data/WIP && \
    chown -R irisowner:irisowner /data

USER irisowner

# Copiar código fuente
WORKDIR /opt/irisapp
COPY --chown=irisowner:irisowner src /opt/irisapp/iris/src/
COPY --chown=irisowner:irisowner Installer.cls /opt/irisapp/
COPY --chown=irisowner:irisowner iris.script /opt/irisapp/

# Ejecutar script de inicialización
# Nota: Preferir inicialización manual si el script falla
RUN iris start IRIS && \
    iris session IRIS < /opt/irisapp/iris.script && \
    iris stop IRIS quietly
```

**⚠️ IMPORTANTE para ARM64 (Apple Silicon):**
- Rutas de librerías: `/usr/lib/` (no `/usr/lib64/`)
- Verificar con: `find /usr -name "libmaodbc.so"` o `find /usr -name "psqlodbcw.so"`

### 7.3 Comandos Docker Útiles

```bash
# Reconstruir todo desde cero
docker compose down -v  # -v elimina volúmenes
docker compose build --no-cache
docker compose up -d

# Ver logs en tiempo real
docker compose logs -f iris

# Ejecutar comando en contenedor
docker exec -it iris102 bash

# Conectar a terminal IRIS
docker exec -it iris102 iris session IRIS -U DEMO

# Copiar archivo al contenedor
docker cp archivo.cls iris102:/opt/irisapp/iris/src/demo/prod/

# Ver procesos IRIS
docker exec iris102 iris session IRIS -U %SYS "##class(%SYSTEM.Process).TerminalList()"

# Reiniciar solo IRIS (sin recrear contenedor)
docker exec iris102 iris restart IRIS quietly
```

### 7.4 Limpieza y Mantenimiento

```bash
# Limpiar datos de IRIS (mantener código)
docker volume rm iris102_iris-data

# Limpiar bases de datos externas
docker volume rm iris102_mysql-data iris102_postgres-data

# Limpiar todo el proyecto
docker compose down -v
docker system prune -a

# Ver uso de espacio
docker system df
```

---

## 8. Testing y Validación

### 8.1 Preparación de Datos de Prueba

```bash
# Estructura de carpeta samples
data/samples/
├── test_basic.csv        # Caso básico (5-10 registros válidos)
├── test_large.csv        # Caso con muchos registros (1000+)
├── test_with_errors.csv  # Registros con errores de validación
├── test_empty.csv        # Archivo vacío
└── test_malformed.csv    # CSV mal formado
```

**test_basic.csv:**
```csv
id,name,age,city
1,Juan,30,Madrid
2,Maria,25,Barcelona
3,Carlos,35,Valencia
4,Ana,28,Sevilla
5,Pedro,32,Bilbao
```

### 8.2 Script de Prueba End-to-End

```bash
#!/bin/bash
# test_e2e.sh

echo "=== Test End-to-End iris102 ==="

# 1. Limpiar bases de datos
echo "Limpiando bases de datos..."
docker exec iris102-mysql mysql -u demo -pdemo_pass demo -e "TRUNCATE TABLE csv_records;"
docker exec iris102-postgres psql -U demo -d demo -c "TRUNCATE TABLE csv_records;"

# 2. Copiar archivo de prueba
echo "Copiando archivo de prueba..."
cp data/samples/test_basic.csv data/IN/test_$(date +%s).csv

# 3. Esperar procesamiento
echo "Esperando procesamiento (30s)..."
sleep 30

# 4. Verificar MySQL
echo "Verificando MySQL..."
MYSQL_COUNT=$(docker exec iris102-mysql mysql -u demo -pdemo_pass demo -se "SELECT COUNT(*) FROM csv_records;")
echo "  Registros en MySQL: $MYSQL_COUNT"

# 5. Verificar PostgreSQL
echo "Verificando PostgreSQL..."
PG_COUNT=$(docker exec iris102-postgres psql -U demo -d demo -tAc "SELECT COUNT(*) FROM csv_records;")
echo "  Registros en PostgreSQL: $PG_COUNT"

# 6. Verificar archivos procesados
echo "Archivos en OUT:"
ls -lh data/OUT/

# 7. Resultado
if [ "$MYSQL_COUNT" -gt 0 ] && [ "$PG_COUNT" -gt 0 ]; then
    echo "✅ Test PASSED"
    exit 0
else
    echo "❌ Test FAILED"
    exit 1
fi
```

### 8.3 Validación desde ObjectScript

```objectscript
/// Smoke test para validar Production
ClassMethod RunSmokeTests() As %Status
{
    Set allOK = 1
    
    // 1. Verificar Production está corriendo
    If '##class(Ens.Director).IsProductionRunning() {
        Write "❌ Production no está corriendo", !
        Set allOK = 0
    } Else {
        Write "✅ Production corriendo", !
    }
    
    // 2. Verificar conectividad MySQL
    Try {
        Set op = ##class(Demo.MySQL.Operation).%New()
        Set op.Adapter = ##class(EnsLib.SQL.OutboundAdapter).%New()
        Set op.Adapter.DSN = "MySQL-Demo"
        Set status = op.TestConnection()
        If $$$ISERR(status) {
            Write "❌ MySQL connection failed", !
            Set allOK = 0
        } Else {
            Write "✅ MySQL connection OK", !
        }
    } Catch ex {
        Write "❌ MySQL test exception: ", ex.DisplayString(), !
        Set allOK = 0
    }
    
    // 3. Verificar conectividad PostgreSQL
    Try {
        Set op = ##class(Demo.Postgres.Operation).%New()
        Set op.Adapter = ##class(EnsLib.SQL.OutboundAdapter).%New()
        Set op.Adapter.DSN = "PostgreSQL-Demo"
        Set status = op.TestConnection()
        If $$$ISERR(status) {
            Write "❌ PostgreSQL connection failed", !
            Set allOK = 0
        } Else {
            Write "✅ PostgreSQL connection OK", !
        }
    } Catch ex {
        Write "❌ PostgreSQL test exception: ", ex.DisplayString(), !
        Set allOK = 0
    }
    
    If allOK {
        Write !, "✅ All smoke tests PASSED", !
        Return $$$OK
    } Else {
        Write !, "❌ Some tests FAILED", !
        Return $$$ERROR(5001, "Smoke tests failed")
    }
}

// Ejecutar desde terminal
Do ##class(Demo.Util.Testing).RunSmokeTests()
```

---

## 9. Errores Comunes y Soluciones

### 9.1 Namespace ya existe

**Error:**
```
ERROR #5540: Namespace 'DEMO' already exists
```

**Solución:**
```bash
# Opción 1: Eliminar volumen de datos IRIS
docker compose down -v

# Opción 2: Renombrar/eliminar namespace desde terminal
docker exec -it iris102 iris session IRIS -U %SYS
> Do ##class(%SYS.Namespace).Delete("DEMO")
```

### 9.2 Compilation fails con dependencias

**Error:**
```
ERROR #5351: Class 'Demo.Msg.FileProcessRequest' does not exist
```

**Solución:**
```objectscript
// Compilar en orden correcto (mensajes primero)
Do $system.OBJ.Compile("Demo.Msg.FileProcessRequest", "ck")
Do $system.OBJ.Compile("Demo.Msg.FileProcessResponse", "ck")
Do $system.OBJ.Compile("Demo.FileService", "ck")
Do $system.OBJ.Compile("Demo.Process", "ck")

// O usar compilación recursiva
Do $system.OBJ.CompilePackage("Demo", "ckr")
```

### 9.3 ODBC Connection Failed

**Error:**
```
[SQLSTATE: 08001] [unixODBC][Driver Manager]Data source name not found
```

**Solución:**
```bash
# 1. Verificar DSN existe
docker exec iris102 odbcinst -q -s

# 2. Verificar odbc.ini
docker exec iris102 cat /etc/odbc.ini

# 3. Verificar drivers
docker exec iris102 odbcinst -q -d

# 4. Test manual
docker exec iris102 isql MySQL-Demo demo demo_pass -v

# 5. Si falla, verificar nombre del DSN en Production.cls
<Setting Target="Adapter" Name="DSN">MySQL-Demo</Setting>  # Debe coincidir con [MySQL-Demo]
```

### 9.4 File Not Found en Process

**Error:**
```
Cannot read file: /data/WIP/archivo.csv
```

**Causa:** Arquitectura incorrecta (ver sección 5.2)

**Solución:** Pasar contenido en mensaje, no FilePath.

### 9.5 Production no actualiza después de cambios

**Solución:**
```objectscript
// 1. Compilar clase
Do $system.OBJ.Compile("Demo.Production", "ck")

// 2. CRÍTICO: UpdateProduction
Do ##class(Ens.Director).UpdateProduction()

// 3. Si no funciona, reiniciar Production
Do ##class(Ens.Director).StopProduction()
Do ##class(Ens.Director).StartProduction("Demo.Production")
```

### 9.6 ARM64 (Apple Silicon) - Library not found

**Error:**
```
Can't open lib '/usr/lib64/libmaodbc.so'
```

**Solución:**
```bash
# Encontrar ruta correcta
docker exec iris102 find /usr -name "libmaodbc.so"

# Actualizar odbcinst.ini con ruta correcta
# ARM64: /usr/lib/libmaodbc.so
# x86_64: /usr/lib64/libmaodbc.so
```

### 9.7 Messages no llegan a Operations

**Diagnóstico:**
1. Abrir Visual Trace
2. Verificar que Process envía mensajes
3. Verificar nombres de targets coinciden

**Causas comunes:**
- Nombre de target incorrecto: `MySQLOperation` vs `MySQL-Operation`
- Settings no configurados en Production.cls
- Process tiene error antes de enviar mensaje

**Solución:**
```objectscript
// En Process, verificar propiedad existe
Property MySQLTarget As %String [ InitialExpression = "MySQLOperation" ];

// En Production.cls
<Setting Target="Host" Name="MySQLTarget">MySQLOperation</Setting>

// Verificar target en SendRequestSync
Set status = ..SendRequestSync(..MySQLTarget, request, .response)
```

---

## 10. Checklist de Proyecto Nuevo

### 10.1 Setup Inicial

- [ ] Crear estructura de directorios
- [ ] Configurar docker-compose.yml con healthchecks
- [ ] Crear Dockerfile con ODBC si necesario
- [ ] Configurar odbc.ini y odbcinst.ini
- [ ] Crear volúmenes para código fuente (read-only)
- [ ] Crear script de inicialización (iris.script)
- [ ] Documentar en README.md

### 10.2 Desarrollo

- [ ] Definir namespaces y packages
- [ ] Crear clases de mensajes primero
- [ ] Implementar Business Operations (integración externa)
- [ ] Implementar Business Processes (lógica de negocio)
- [ ] Implementar Business Services (entrada de datos)
- [ ] Crear Production.cls con XData
- [ ] Configurar Settings en Production

### 10.3 Testing

- [ ] Crear datos de prueba (samples)
- [ ] Implementar métodos TestConnection() en Operations
- [ ] Crear smoke tests
- [ ] Probar casos de error
- [ ] Verificar Visual Trace muestra flujo completo
- [ ] Validar logs y mensajes de error

### 10.4 Deployment

- [ ] Compilar todas las clases sin errores
- [ ] Habilitar Interoperability en namespace
- [ ] Crear credenciales necesarias
- [ ] Iniciar Production
- [ ] Verificar todos los componentes Running
- [ ] Ejecutar prueba end-to-end
- [ ] Documentar proceso de deployment

---

## 11. Referencias y Recursos

### 11.1 Documentación Oficial

- [InterSystems IRIS Documentation](https://docs.intersystems.com/)
- [Interoperability Guide](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls)
- [ObjectScript Reference](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GCOS)
- [SQL Gateway](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=ESQL)

### 11.2 Comunidad

- [InterSystems Developer Community](https://community.intersystems.com/)
- [GitHub - InterSystems Examples](https://github.com/intersystems-community)

### 11.3 Herramientas

- [VS Code IRIS Extension](https://marketplace.visualstudio.com/items?itemName=intersystems-community.vscode-objectscript)
- [Docker Hub - IRIS Community](https://hub.docker.com/r/intersystemsdc/iris-community)

---

## 12. Conclusiones y Recomendaciones Finales

### 12.1 Lecciones Más Importantes

1. **Arquitectura de File Processing:** Siempre pasar contenido en mensajes, nunca paths de archivos que pueden desaparecer.

2. **ODBC vs External Language Servers:** Son conceptos diferentes. Config.Gateways NO es para SQL.

3. **Visual Trace es tu mejor amigo:** Úsalo siempre para debugging de flujo de mensajes.

4. **UpdateProduction() es crítico:** Después de cambios en XData, no olvides ejecutarlo.

5. **Compilación en orden:** Mensajes → Operations → Processes → Services → Production

6. **Volúmenes Docker:** Facilitan mucho el desarrollo, úsalos read-only por seguridad.

7. **ARM64 vs x86_64:** Rutas de librerías son diferentes, documenta para tu arquitectura.

### 12.2 Para Próximos Proyectos

- Empezar con smoke tests y datos de prueba
- Documentar desde el principio
- Usar git desde día 1
- Implementar logging estratégico
- No confiar en heredocs para ObjectScript
- Validar conectividad antes de implementar lógica
- Usar Visual Trace desde el primer test

---

**Fecha de última actualización:** 17 de octubre de 2025  
**Versión:** 1.0  
**Proyecto:** iris102 - CSV to MySQL/PostgreSQL via IRIS Interoperability

