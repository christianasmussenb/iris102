# ✅ Sprint 5 - Archivos de Reconstrucción Creados

**Fecha:** 20 Octubre 2025  
**Status:** PREPARADO PARA CONSTRUCCIÓN

---

## 📦 Archivos Nuevos Creados

### 1. Infraestructura Docker

| Archivo | Descripción | Líneas |
|---------|-------------|--------|
| `iris/Dockerfile.new` | Dockerfile limpio con IRIS 2024.3 + Java 11 + JDBC drivers | 116 |
| `docker-compose.new.yml` | Orquestación de 3 servicios (IRIS + MySQL + PostgreSQL) | 130 |

**Características clave del Dockerfile.new:**
- ✅ Base: `intersystemsdc/irishealth-community:2024.3`
- ✅ OpenJDK 11 JDK instalado
- ✅ MySQL Connector/J 8.0.33 descargado desde Maven Central
- ✅ PostgreSQL JDBC 42.6.0 descargado desde postgresql.org
- ✅ `JAVA_HOME` y `JDBC_CLASSPATH` configurados
- ✅ Directorio `/opt/irisapp/jdbc/` con drivers
- ✅ **Sin ODBC** (completamente eliminado)

**Características del docker-compose.new.yml:**
- ✅ 3 servicios: `iris`, `mysql`, `postgres`
- ✅ Health checks configurados
- ✅ Orden de inicio: DB → IRIS
- ✅ Volúmenes persistentes
- ✅ Red `iris102_network`

---

### 2. Instalación y Configuración

| Archivo | Descripción | Líneas |
|---------|-------------|--------|
| `iris/Installer.new.cls` | Clase ObjectScript para instalación con soporte JDBC | 262 |
| `iris/iris.new.script` | Script bash de inicialización de IRIS | 130 |

**Características del Installer.new.cls:**
- ✅ Importación de fuentes
- ✅ Compilación de clases
- ✅ **Configuración de Java Gateway** (NUEVO)
- ✅ **Pruebas de conectividad JDBC** (NUEVO)
- ✅ Inicio automático de Production
- ✅ Manejo de errores robusto

**Métodos principales:**
1. `Run()` - Método principal de instalación
2. `ImportSources()` - Importar clases desde `/opt/irisapp/src`
3. `CompileAll()` - Compilar todo el código
4. `SetupJavaGateway()` - Configurar `%Net.Remote.Service` con classpath JDBC
5. `TestJDBCConnectivity()` - Probar drivers MySQL y PostgreSQL
6. `SetupProduction()` - Iniciar `Demo.Production`

---

### 3. Automatización y Documentación

| Archivo | Descripción | Líneas |
|---------|-------------|--------|
| `rebuild.sh` | Script automatizado de reconstrucción completa | 260 |
| `SPRINT5_REBUILD.md` | Documentación completa del proceso | 340 |

**Características del rebuild.sh:**
- ✅ Limpieza completa de ambiente anterior
- ✅ Construcción de imágenes sin cache
- ✅ Inicio ordenado de servicios
- ✅ Validaciones automáticas
- ✅ Output con colores
- ✅ Manejo de errores

**Fases del script:**
1. Detener y limpiar containers/volúmenes/imágenes
2. Verificar archivos necesarios
3. Construcción de imágenes Docker
4. Inicio de MySQL/PostgreSQL
5. Inicio de IRIS
6. Validaciones (drivers, Java, tablas DB)
7. Resumen con accesos y próximos pasos

---

## 🚀 Cómo Ejecutar la Reconstrucción

### Opción 1: Script Automatizado (RECOMENDADO)

```bash
cd /Users/cab/VSCODE/iris102
./rebuild.sh
```

Este script ejecutará automáticamente:
- ✓ Limpieza completa
- ✓ Build de imágenes
- ✓ Inicio de servicios
- ✓ Validaciones
- ✓ Reporte de status

**Tiempo estimado:** 8-12 minutos

---

### Opción 2: Paso a Paso Manual

```bash
# 1. Limpiar ambiente
docker-compose down -v
docker container prune -f
docker volume prune -f

# 2. Construir imágenes
docker-compose -f docker-compose.new.yml build --no-cache

# 3. Iniciar servicios
docker-compose -f docker-compose.new.yml up -d

# 4. Ver logs
docker-compose -f docker-compose.new.yml logs -f iris
```

---

## ✅ Validaciones Post-Construcción

### 1. Verificar containers corriendo
```bash
docker-compose -f docker-compose.new.yml ps

# Esperado:
# iris102          Up      52773->52773, 1972->1972
# iris102-mysql    Up      3306->3306
# iris102-postgres Up      5432->5432
```

### 2. Verificar JDBC drivers en filesystem
```bash
docker exec -it iris102 ls -lh /opt/irisapp/jdbc/

# Esperado:
# mysql-connector-j-8.0.33.jar    2.4M
# postgresql-42.6.0.jar           1.1M
```

### 3. Verificar Java Gateway en IRIS
```objectscript
// En Terminal IRIS (namespace DEMO)
ZN "DEMO"

Set gw = ##class(%Net.Remote.Gateway).%New()
Set status = gw.%Connect("127.0.0.1", 55556, $NAMESPACE)
Write "Status: ", $SYSTEM.Status.GetErrorText(status),!

// Probar drivers
Set class = gw.%New("java.lang.Class")
Do class.forName("com.mysql.cj.jdbc.Driver")
Write "MySQL Driver: OK",!

Do class.forName("org.postgresql.Driver")
Write "PostgreSQL Driver: OK",!

Do gw.%Disconnect()
```

### 4. Verificar Production corriendo
- Acceder a: http://localhost:52773/csp/demo/EnsPortal.ProductionConfig.zen
- Verificar status: **RUNNING**
- Componentes visibles:
  - Demo.FileService
  - Demo.Process
  - Demo.MySQL.Operation (aún ODBC - se reemplazará)
  - Demo.Postgres.Operation (aún ODBC - se reemplazará)

---

## 📋 Próximos Pasos Después de la Construcción

### Fase 1: Crear JDBC Operations (Nuevo código)

**Archivos a crear:**
1. `iris/src/demo/prod/Demo.MySQL.JDBCOperation.cls`
2. `iris/src/demo/prod/Demo.Postgres.JDBCOperation.cls`

**Estructura base:**
```objectscript
Class Demo.MySQL.JDBCOperation Extends Ens.BusinessOperation
{
    Property Gateway As %Net.Remote.Gateway;
    Property Connection As %ObjectHandle;  // java.sql.Connection
    
    Method OnInit() As %Status
    {
        // Connect to Java Gateway
        // Load JDBC driver
        // Create connection to MySQL
    }
    
    Method Insert(pRequest As Demo.Msg.DatabaseInsertRequest) As Demo.Msg.DatabaseInsertResponse
    {
        // Execute INSERT using JDBC
    }
}
```

### Fase 2: Actualizar Production

Modificar `Demo.Production.cls`:
- Reemplazar `Demo.MySQL.Operation` con `Demo.MySQL.JDBCOperation`
- Reemplazar `Demo.Postgres.Operation` con `Demo.Postgres.JDBCOperation`
- Eliminar configuraciones ODBC (DSN)

### Fase 3: Testing

```bash
# Copiar archivo de prueba
docker cp data/samples/test_basic.csv iris102:/data/IN/

# Verificar logs
docker-compose -f docker-compose.new.yml logs -f iris

# Verificar Visual Trace
# http://localhost:52773/csp/demo/EnsPortal.VisualTrace.zen

# Verificar registros en DB
docker exec -it iris102-mysql mysql -u demo -pdemo -e "SELECT COUNT(*) FROM demo.csv_records;"
docker exec -it iris102-postgres psql -U demo -d demo -c "SELECT COUNT(*) FROM csv_records;"
```

---

## 🔄 Comparación: Antes vs Después

### ODBC (Sprint 4) ❌

```
IRIS Container
├─ UnixODBC 2.3.12
├─ MariaDB ODBC Driver
├─ PostgreSQL ODBC Driver
├─ /etc/odbc.ini (DSN config)
└─ EnsLib.SQL.OutboundAdapter
   └─ ERROR #6022 (irresolvable)
```

### JDBC (Sprint 5) ✅

```
IRIS Container
├─ OpenJDK 11 JDK
├─ mysql-connector-j-8.0.33.jar
├─ postgresql-42.6.0.jar
├─ Java Gateway (port 55556)
│  └─ CLASSPATH: /opt/irisapp/jdbc/*.jar
└─ %Net.Remote.Gateway
   └─ java.sql.Connection (estándar)
```

---

## 📊 Métricas del Rebuild

| Métrica | Valor |
|---------|-------|
| **Archivos creados** | 5 nuevos |
| **Líneas de código/config** | ~1,238 |
| **Tiempo de construcción** | 8-12 min |
| **Tamaño imagen IRIS** | ~2.5 GB |
| **JDBC drivers** | 3.5 MB total |
| **Eliminado** | Toda config ODBC |

---

## ⚠️ Troubleshooting Común

### Error: "Cannot download JDBC drivers"

**Solución:** Verificar conectividad a internet durante build

```bash
# Probar descarga manual
wget https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/8.0.33/mysql-connector-j-8.0.33.jar
wget https://jdbc.postgresql.org/download/postgresql-42.6.0.jar
```

### Error: "Java Gateway connection failed"

**Solución:** Verificar que Java Gateway esté configurado y corriendo

```objectscript
// En Terminal IRIS
Set svc = ##class(%Net.Remote.Service).%OpenId("JavaGateway")
Write svc.Port,!  // Debería ser 55556
Do svc.%Save()

// Reiniciar gateway
Do ##class(%Net.Remote.Service).StopGateway("JavaGateway")
Do ##class(%Net.Remote.Service).StartGateway("JavaGateway")
```

### Error: "Production fails to start"

**Solución:** Revisar logs de compilación

```bash
docker-compose -f docker-compose.new.yml logs iris | grep -i error
```

---

## 📞 Soporte y Referencias

**Documentación IRIS:**
- Java Gateway: https://docs.intersystems.com/iris20243/csp/docbook/Doc.View.cls?KEY=BJAVA
- JDBC Connectivity: https://docs.intersystems.com/iris20243/csp/docbook/Doc.View.cls?KEY=BGCL

**JDBC Drivers:**
- MySQL: https://dev.mysql.com/doc/connector-j/8.0/en/
- PostgreSQL: https://jdbc.postgresql.org/documentation/

**Proyecto:**
- Plan completo: `PLAN_MIGRACION_JDBC.md`
- Problema ODBC: `PROBLEMA_ODBC_DOCUMENTADO.md`
- Estado actual: `ESTADO_PROYECTO.md`

---

**Estado:** ✅ **LISTO PARA EJECUTAR**

Ejecuta `./rebuild.sh` para comenzar la reconstrucción completa.
