# Problema ODBC con IRIS - Documentación Completa

## Fecha: 17 de Octubre 2025

## Resumen Ejecutivo

A pesar de múltiples intentos de configuración y troubleshooting exhaustivo, **EnsLib.SQL.OutboundAdapter NO puede establecer conexiones ODBC** a MySQL y PostgreSQL desde IRIS Community Edition.

**Paradoja Critical**: La herramienta de línea de comandos `isql` conecta perfectamente con ambas bases de datos usando los mismos DSN, pero IRIS falla consistentemente.

## Síntomas

### Error Principal
```
ERROR #6022: Gateway failed: SQLConnect, with timeout of 15 failed
SQLState: (??0) 
NativeError: [2002] (MySQL)
NativeError: [101] (PostgreSQL)
Message: ???????????????????????????)??????...
```

### Características del Error
- **Mensaje corrupto**: Los caracteres `???????...` indican problema de codificación o mensaje no interpretable
- **Consistente**: Ocurre en TODAS las Operations que usan EnsLib.SQL.OutboundAdapter
- **Timeout**: Siempre menciona "timeout of 15 failed" aunque no es un timeout real
- **SQLState corrupto**: `(??0)` en lugar de un código SQL State válido

## Configuraciones Probadas (Todas Fallidas)

### 1. Configuración con IPs Directas
```ini
[MySQL-Demo]
Driver = /usr/lib/x86_64-linux-gnu/odbc/libmaodbc.so
SERVER = 172.18.0.3
PORT = 3306
DATABASE = demo
UID = demo
PWD = demo_pass
```
**Resultado**: ERROR #6022

### 2. Configuración con Hostnames
```ini
[MySQL-Demo]
Driver = MariaDB ODBC 3.1 Driver
Server = mysql
Port = 3306
Database = demo
USER = demo
PASSWORD = demo_pass
```
**Resultado**: ERROR #6022

### 3. Con Credenciales de IRIS
```xml
<Setting Target="Adapter" Name="DSN">MySQL-Demo</Setting>
<Setting Target="Adapter" Name="Credentials">MySQL-Demo-Credentials</Setting>
```
**Resultado**: ERROR #6022

### 4. Sin Credenciales (Embedded en DSN)
```xml
<Setting Target="Adapter" Name="DSN">MySQL-Demo</Setting>
<!-- Sin Credentials -->
```
**Resultado**: ERROR #6022

### 5. Diferentes Sintaxis de Propiedades
- MySQL: `SERVER` vs `Server`, `UID` vs `USER`, `PWD` vs `PASSWORD`
- PostgreSQL: `Servername` vs `Server`, `Username` vs `UID`
- Probadas todas las combinaciones
**Resultado**: ERROR #6022 en todos los casos

### 6. Reinicio Completo de IRIS
- Stop Production
- Restart IRIS Container
- Recargar configuración ODBC
**Resultado**: ERROR #6022 persiste

## Evidencia de Conectividad Funcionando

### isql - Funciona Perfectamente
```bash
$ echo "SELECT 1;" | isql -b MySQL-Demo
+---------------------+
| 1                   |
+---------------------+
| 1                   |
+---------------------+
SQLRowCount returns 1
1 rows fetched
```

```bash
$ echo "SELECT 1;" | isql -b PostgreSQL-Demo
+------------+
| 1          |
+------------+
| 1          |
+------------+
SQLRowCount returns 1
1 rows fetched
```

### Conectividad de Red
```bash
$ docker exec iris102 bash -c 'timeout 2 bash -c "echo > /dev/tcp/172.18.0.3/3306"'
# Exitoso

$ docker exec iris102 bash -c 'timeout 2 bash -c "echo > /dev/tcp/172.18.0.2/5432"'
# Exitoso
```

### Variables de Entorno
```bash
IRIS Process:    ODBCINI=/usr/irissys/mgr/irisodbc.ini
Shell (isql):    ODBCINI=/etc/odbc.ini
```

**Ambos archivos contienen DSN válidos y probados**.

## Pruebas de Código Direct

### Test con %SQLGatewayConnection
```objectscript
Set gtwConn = ##class(%SQLGatewayConnection).%New()
Set result = gtwConn.Connect("MySQL-Demo", "demo", "demo_pass")
// Result: 0 (FAILED)
// GatewayStatus: 0
// Error: SQLConnect, with timeout of 0 failed
```

### Test con EnsLib.SQL.OutboundAdapter
```objectscript
Set adapter = ##class(EnsLib.SQL.OutboundAdapter).%New()
Set adapter.DSN = "MySQL-Demo"
Do adapter.Connect()
// Throws exception: ERROR #6022
```

**Ambos métodos fallan**, lo que indica que el problema es a nivel de la integración IRIS-ODBC, no específico del adapter de Interoperability.

## Análisis Técnico

### Posibles Causas

1. **Limitación de IRIS Community Edition**
   - Es posible que IRIS CE tenga restricciones en conexiones ODBC externas
   - No hay documentación clara sobre limitaciones de CE vs versión comercial

2. **Problema de Librería ODBC**
   - IRIS usa `LD_LIBRARY_PATH=/usr/irissys/bin`
   - Podría haber conflicto con librerías ODBC del sistema
   - UnixODBC vs iODBC incompatibilidades

3. **Codificación de Mensajes**
   - Los mensajes de error corruptos (`???????...`) sugieren problema de charset
   - IRIS podría no interpretar correctamente mensajes UTF-8 del driver

4. **Timeout Incorrecto**
   - Los tests muestran "timeout of 0" en algunos casos
   - Podría haber un bug en cómo IRIS pasa parámetros al driver ODBC

5. **Permisos o Contexto de Ejecución**
   - Usuario `irisowner` ejecuta tanto IRIS como isql exitosamente
   - No parece ser problema de permisos

### Lo Que NO Es el Problema

- ❌ Configuración de red (ping/telnet funcionan)
- ❌ Credenciales (probadas múltiples formas)
- ❌ Sintaxis de DSN (isql usa los mismos DSN exitosamente)
- ❌ Drivers ODBC (instalados y funcionando con isql)
- ❌ Bases de datos (MySQL y PostgreSQL operando normalmente)

## Impacto en el Proyecto

### Componentes Afectados
- ✅ **Demo.FileService**: Funcionando correctamente
- ✅ **Demo.Process**: Funcionando correctamente (parsea CSV de memoria)
- ✅ **Demo.Msg.***: Todas las clases de mensaje funcionando
- ❌ **Demo.MySQL.Operation**: Bloqueado por ODBC
- ❌ **Demo.Postgres.Operation**: Bloqueado por ODBC

### Estado Actual
- Archivos CSV son detectados y procesados
- Parsing funciona correctamente (arquitectura de Stream → String implementada)
- Mensajes fluyen correctamente por el Process
- **BLOCKER**: Operations no pueden insertar en bases de datos
- Resultado: Archivos terminan en `/data/OUT/` con sufijo `__failed`
- **0 registros insertados** en ambas bases de datos

## Referencias Consultadas

1. **InterSystems Community**: "Using ODBC SQL Gateway programmatically"
   - https://community.intersystems.com/post/using-odbc-sql-gateway-programmatically
   - Confirma uso de `%SQLGatewayConnection` pero no resuelve el error

2. **Documentación IRIS**:
   - EnsLib.SQL.OutboundAdapter
   - %SQLGatewayConnection
   - SQL Gateway Configuration

3. **UnixODBC**:
   - Version 2.3.12 instalada
   - Drivers MariaDB ODBC 3.1 y PostgreSQL Unicode funcionando con isql

## Decisión: Cambio a JDBC

Dado que:
1. Se han agotado todas las opciones de configuración ODBC
2. No hay documentación clara sobre el error #6022 en este contexto
3. `isql` funciona pero IRIS no puede usar los mismos DSN
4. El proyecto necesita avanzar

**Se decide cambiar a JDBC para el siguiente sprint**.

### Ventajas de JDBC
- Drivers Java más maduros y documentados
- No depende de configuración ODBC del sistema
- Mejor documentación de errores
- Más ejemplos en comunidad InterSystems
- Gateway Server de IRIS más robusto para JDBC

### Trabajo Requerido
- Configurar Java Gateway Server en IRIS
- Instalar JDBC drivers (MySQL Connector/J, PostgreSQL JDBC)
- Modificar Operations para usar EnsLib.SQL.OutboundAdapter con JDBC
- Actualizar configuración de Production
- Testing completo del nuevo stack

## Lecciones Aprendidas

1. **IRIS usa su propio archivo ODBC**: `/usr/irissys/mgr/irisodbc.ini`, NO `/etc/odbc.ini`
2. **isql != IRIS**: Herramientas de línea de comandos no garantizan compatibilidad con IRIS
3. **Variables de entorno**: `ODBCINI` del proceso IRIS es diferente al shell
4. **Community Edition**: Posibles limitaciones no documentadas
5. **Arquitectura FileService**: Pasar contenido en mensaje (no paths) es la forma correcta
6. **Debugging**: Visual Trace en Portal es esencial para ver flujo de mensajes

## Próximos Pasos (Sprint JDBC)

Ver: `PLAN_MIGRACION_JDBC.md`

---

**Documentado por**: GitHub Copilot AI Assistant  
**Fecha**: 17 de Octubre 2025  
**Tiempo invertido en troubleshooting ODBC**: ~5 horas  
**Resultado**: Problema no resuelto, cambio de estrategia aprobado
