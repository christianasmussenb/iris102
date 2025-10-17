# Plan de Migración a JDBC - Sprint Siguiente

## Objetivo

Reemplazar las conexiones ODBC fallidas por conexiones JDBC funcionales para permitir inserciones en MySQL y PostgreSQL desde IRIS.

## Estado Actual del Proyecto

### ✅ Completado (Mantener)
- Arquitectura FileService lee Stream y pasa contenido en mensaje
- Demo.Msg.FileProcessRequest con propiedad CSVContent
- Demo.Process parsea CSV desde string en memoria
- Flujo de mensajes FileService → Process → Operations funciona
- Todas las clases compiladas correctamente

### ❌ Bloqueado (Requiere Cambio)
- Demo.MySQL.Operation usando ODBC → cambiar a JDBC
- Demo.Postgres.Operation usando ODBC → cambiar a JDBC
- Inserciones en bases de datos → 0 registros actualmente

## Fases del Sprint JDBC

### Fase 1: Investigación y Preparación (Día 1)

#### 1.1 Investigar Java Gateway en IRIS
- [ ] Leer documentación: https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=EJVG
- [ ] Verificar si Java Gateway está disponible en IRIS Community Edition
- [ ] Identificar versión de Java requerida (JDK 11+)
- [ ] Confirmar compatibilidad con container Docker actual

#### 1.2 Descargar JDBC Drivers
- [ ] MySQL Connector/J: https://dev.mysql.com/downloads/connector/j/
  - Versión recomendada: 8.0.33 o superior
  - Archivo: `mysql-connector-j-8.0.33.jar`
- [ ] PostgreSQL JDBC: https://jdbc.postgresql.org/download/
  - Versión recomendada: 42.6.0 o superior
  - Archivo: `postgresql-42.6.0.jar`

#### 1.3 Preparar Entorno
- [ ] Verificar si Java está instalado en container IRIS
- [ ] Instalar JRE/JDK si no está disponible
- [ ] Crear directorio `/opt/irisapp/jdbc/` para drivers
- [ ] Copiar JAR files al contenedor

### Fase 2: Configuración de Java Gateway (Día 1-2)

#### 2.1 Configurar Java Gateway Server
```objectscript
// Configuración en %SYS
Set gateway = ##class(%Net.Remote.Service).%New()
Set gateway.Name = "JavaGateway"
Set gateway.Gateway = "127.0.0.1:55555"
Set gateway.HeapSize = 256  // MB
Set gateway.ClassPath = "/opt/irisapp/jdbc/mysql-connector-j-8.0.33.jar:/opt/irisapp/jdbc/postgresql-42.6.0.jar"
Set status = gateway.%Save()
```

#### 2.2 Iniciar Java Gateway
```objectscript
Do ##class(%Net.Remote.Service).StartGateway("JavaGateway")
```

#### 2.3 Verificar Conexión
```objectscript
Set gateway = ##class(%Net.Remote.Gateway).%New()
Set status = gateway.%Connect("127.0.0.1", "55555", "JavaGateway")
Write "Gateway Status: ", status, !
```

### Fase 3: Crear Clases JDBC Operations (Día 2)

#### 3.1 Crear Demo.MySQL.JDBCOperation

**Archivo**: `iris/src/demo/prod/Demo.MySQL.JDBCOperation.cls`

```objectscript
Class Demo.MySQL.JDBCOperation Extends Ens.BusinessOperation
{

Parameter ADAPTER = "EnsLib.SQL.OutboundAdapter";

Parameter INVOCATION = "Queue";

/// JDBC Connection String
Property JDBCConnectionString As %String [ InitialExpression = "jdbc:mysql://mysql:3306/demo?useSSL=false&allowPublicKeyRetrieval=true" ];

/// JDBC Driver Class
Property JDBCDriver As %String [ InitialExpression = "com.mysql.cj.jdbc.Driver" ];

/// JDBC Username
Property JDBCUsername As %String [ InitialExpression = "demo" ];

/// JDBC Password (encrypted in production)
Property JDBCPassword As %String [ InitialExpression = "demo_pass" ];

/// Handle database insert request
Method OnMessage(pRequest As Demo.Msg.DatabaseInsertRequest, Output pResponse As Demo.Msg.DatabaseInsertResponse) As %Status
{
    Set status = $$$OK
    Set pResponse = ##class(Demo.Msg.DatabaseInsertResponse).%New()
    
    Try {
        Set pResponse.DatabaseType = "MySQL"
        Set pResponse.RequestId = pRequest.RequestId
        Set pResponse.TotalRecords = pRequest.TotalRecords
        
        // Use JDBC Connection via Adapter
        Set adapter = ..Adapter
        If 'adapter.Connected {
            $$$ThrowOnError(adapter.Connect())
        }
        
        // Prepare batch insert
        Set insertCount = 0
        For i=1:1:pRequest.Records.Count() {
            Set record = pRequest.Records.GetAt(i)
            
            Set sql = "INSERT INTO csv_records (csv_id, name, age, city, source_file, file_hash) VALUES (?, ?, ?, ?, ?, ?)"
            
            Set stmt = ##class(%SQL.Statement).%New()
            Set tSC = stmt.%Prepare(sql)
            $$$ThrowOnError(tSC)
            
            Set rs = stmt.%Execute(
                record.CsvId,
                record.Name,
                record.Age,
                record.City,
                pRequest.FileName,
                pRequest.FileHash
            )
            
            If rs.%SQLCODE = 0 {
                Set insertCount = insertCount + 1
            } Else {
                $$$LOGWARNING("Insert failed for record "_i_": "_rs.%Message)
            }
        }
        
        Set pResponse.RecordsInserted = insertCount
        Set pResponse.Success = (insertCount = pRequest.TotalRecords)
        Set pResponse.Message = "Inserted "_insertCount_" of "_pRequest.TotalRecords_" records"
        
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "MySQL.JDBC", pResponse.Message)
        
    } Catch ex {
        Set status = ex.AsStatus()
        Set pResponse.Success = 0
        Set pResponse.Message = "ERROR: "_ex.DisplayString()
        Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "MySQL.JDBC", pResponse.Message)
    }
    
    Quit status
}

}
```

#### 3.2 Crear Demo.Postgres.JDBCOperation

**Archivo**: `iris/src/demo/prod/Demo.Postgres.JDBCOperation.cls`

Similar a MySQL pero con:
```objectscript
Property JDBCConnectionString As %String [ InitialExpression = "jdbc:postgresql://postgres:5432/demo" ];
Property JDBCDriver As %String [ InitialExpression = "org.postgresql.Driver" ];
```

### Fase 4: Actualizar Production Configuration (Día 2)

#### 4.1 Modificar Demo.Production.cls

```xml
<!-- OLD: ODBC Operations -->
<!--
<Item Name="MySQLOperation" ClassName="Demo.MySQL.Operation">
    <Setting Target="Adapter" Name="DSN">MySQL-Demo</Setting>
</Item>
-->

<!-- NEW: JDBC Operations -->
<Item Name="MySQLOperation" ClassName="Demo.MySQL.JDBCOperation">
    <Setting Target="Adapter" Name="JDBCDriver">com.mysql.cj.jdbc.Driver</Setting>
    <Setting Target="Adapter" Name="JDBCConnectionString">jdbc:mysql://mysql:3306/demo</Setting>
    <Setting Target="Adapter" Name="JDBCUsername">demo</Setting>
    <Setting Target="Adapter" Name="JDBCPassword">demo_pass</Setting>
</Item>

<Item Name="PostgreSQLOperation" ClassName="Demo.Postgres.JDBCOperation">
    <Setting Target="Adapter" Name="JDBCDriver">org.postgresql.Driver</Setting>
    <Setting Target="Adapter" Name="JDBCConnectionString">jdbc:postgresql://postgres:5432/demo</Setting>
    <Setting Target="Adapter" Name="JDBCUsername">demo</Setting>
    <Setting Target="Adapter" Name="JDBCPassword">demo_pass</Setting>
</Item>
```

### Fase 5: Testing y Validación (Día 3)

#### 5.1 Test Unitario de Conexión JDBC
```objectscript
ClassMethod TestJDBCConnection() As %Status
{
    Set gateway = ##class(%Net.Remote.Gateway).%New()
    Set status = gateway.%Connect("127.0.0.1", "55555", "JavaGateway")
    
    If status {
        Write "Java Gateway connected!", !
        
        // Load MySQL Driver
        Set driverClass = gateway.%New("com.mysql.cj.jdbc.Driver")
        Write "MySQL Driver loaded: ", $IsObject(driverClass), !
        
        // Test Connection
        Set url = "jdbc:mysql://mysql:3306/demo"
        Set conn = gateway.%New("java.sql.DriverManager").getConnection(url, "demo", "demo_pass")
        
        If $IsObject(conn) {
            Write "MySQL Connection successful!", !
            Do conn.close()
        }
    }
    
    Quit status
}
```

#### 5.2 Test End-to-End
- [ ] Copiar `test_basic.csv` (5 registros) a `/data/IN/`
- [ ] Verificar procesamiento en Visual Trace
- [ ] Confirmar mensajes en Message Viewer
- [ ] Verificar `SELECT COUNT(*) FROM csv_records` en ambas DB
- [ ] Validar que archivos NO terminen con `__failed`
- [ ] Confirmar datos correctos en tablas

#### 5.3 Test de Carga
- [ ] Copiar `test_with_errors.csv` (con registros inválidos)
- [ ] Copiar archivo grande (100+ registros)
- [ ] Verificar manejo de errores
- [ ] Validar performance (tiempo de inserción)

### Fase 6: Corregir Tabla PostgreSQL (Día 3)

**Problema identificado**: Demo.Postgres.Operation referencia tabla `demo_data` pero la tabla real es `csv_records`

- [ ] Buscar todas las referencias a `demo_data` en código
- [ ] Reemplazar por `csv_records`
- [ ] Recompilar
- [ ] Validar con test

### Fase 7: Dockerización (Día 3)

#### 7.1 Actualizar Dockerfile
```dockerfile
# Instalar OpenJDK
RUN apt-get update && apt-get install -y openjdk-11-jre-headless

# Copiar JDBC Drivers
COPY jdbc/*.jar /opt/irisapp/jdbc/

# Configurar CLASSPATH
ENV CLASSPATH=/opt/irisapp/jdbc/mysql-connector-j-8.0.33.jar:/opt/irisapp/jdbc/postgresql-42.6.0.jar
```

#### 7.2 Actualizar iris.script
```objectscript
// Auto-start Java Gateway on container startup
Do ##class(%Net.Remote.Service).StartGateway("JavaGateway")
```

### Fase 8: Documentación (Día 4)

#### 8.1 Actualizar README.md
- [ ] Sección sobre JDBC configuration
- [ ] Requisitos de Java
- [ ] Instrucciones de setup de Java Gateway
- [ ] Troubleshooting de JDBC

#### 8.2 Crear JDBC_SETUP.md
- [ ] Guía paso a paso de configuración
- [ ] Ejemplos de connection strings
- [ ] Configuración de credenciales
- [ ] Monitoreo de Java Gateway

#### 8.3 Actualizar BUENAS_PRACTICAS_IRIS.md
- [ ] Sección: "JDBC vs ODBC en IRIS"
- [ ] Cuando usar cada uno
- [ ] Limitaciones conocidas de ODBC
- [ ] Mejores prácticas de JDBC

## Criterios de Éxito

### Must Have (Obligatorio)
- ✅ Java Gateway configurado y operacional
- ✅ Ambas Operations conectan vía JDBC sin errores
- ✅ Test con `test_basic.csv` inserta 5 registros en ambas DB
- ✅ Visual Trace muestra flujo completo sin errores
- ✅ Archivos procesados NO terminan con `__failed`
- ✅ Query `SELECT COUNT(*)` retorna > 0 en ambas DB

### Should Have (Deseable)
- ✅ Java Gateway inicia automáticamente con container
- ✅ Manejo robusto de errores JDBC
- ✅ Logging detallado de operaciones JDBC
- ✅ Performance aceptable (< 1 seg por 100 registros)
- ✅ Documentación completa

### Nice to Have (Opcional)
- Connection pooling configurado
- Retry logic para transient failures
- Métricas de performance
- Dashboard de monitoreo

## Riesgos y Mitigaciones

### Riesgo 1: Java Gateway no disponible en CE
**Probabilidad**: Baja  
**Impacto**: Alto  
**Mitigación**: Verificar documentación CE antes de empezar. Si no disponible, evaluar actualizar a IRIS Standard Edition.

### Riesgo 2: Performance de JDBC inferior a ODBC
**Probabilidad**: Media  
**Impacto**: Medio  
**Mitigación**: Implementar batch inserts y connection pooling. Benchmark vs requisitos.

### Riesgo 3: Complejidad de configuración
**Probabilidad**: Media  
**Impacto**: Bajo  
**Mitigación**: Documentación detallada, scripts de setup automáticos.

### Riesgo 4: Problemas con drivers JDBC
**Probabilidad**: Baja  
**Impacto**: Medio  
**Mitigación**: Usar versiones estables y bien documentadas. Mantener alternativas (versiones diferentes).

## Recursos Necesarios

### Documentación
- InterSystems IRIS Java Gateway Guide
- MySQL Connector/J Documentation
- PostgreSQL JDBC Documentation
- Docker + Java best practices

### Herramientas
- OpenJDK 11 (en container)
- MySQL Connector/J JAR
- PostgreSQL JDBC JAR
- IRIS Management Portal
- Visual Trace

### Tiempo Estimado
- Investigación: 4 horas
- Configuración inicial: 4 horas
- Desarrollo Operations: 6 horas
- Testing: 4 horas
- Correcciones: 4 horas
- Documentación: 3 horas
- **Total: ~25 horas (3-4 días)**

## Entregables

1. **Código**:
   - `Demo.MySQL.JDBCOperation.cls`
   - `Demo.Postgres.JDBCOperation.cls`
   - `Demo.Production.cls` (actualizado)
   - Scripts de configuración de Java Gateway

2. **Docker**:
   - `Dockerfile` (actualizado con Java)
   - `iris.script` (con auto-start de Gateway)
   - Directorio `jdbc/` con JARs

3. **Documentación**:
   - `JDBC_SETUP.md`
   - `README.md` (actualizado)
   - `BUENAS_PRACTICAS_IRIS.md` (sección JDBC)
   - Este documento (PLAN_MIGRACION_JDBC.md)

4. **Tests**:
   - Test de conexión JDBC
   - Test end-to-end funcional
   - Test de carga (100+ registros)
   - Resultados documentados

## Checklist de Inicio de Sprint

- [ ] Revisar y aprobar este plan
- [ ] Verificar disponibilidad de Java Gateway en IRIS CE
- [ ] Descargar JDBC drivers (MySQL + PostgreSQL)
- [ ] Preparar entorno de desarrollo
- [ ] Crear branch: `feature/jdbc-migration`
- [ ] Comunicar cambio al equipo
- [ ] Actualizar sprint backlog

## Referencias

- [IRIS Java Gateway Documentation](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=EJVG)
- [MySQL Connector/J](https://dev.mysql.com/downloads/connector/j/)
- [PostgreSQL JDBC](https://jdbc.postgresql.org/)
- [InterSystems Community - JDBC Examples](https://community.intersystems.com/tags/jdbc)

---

**Plan creado**: 17 de Octubre 2025  
**Sprint estimado**: 3-4 días  
**Prioridad**: Alta (Blocker actual del proyecto)  
**Aprobación**: Pendiente
