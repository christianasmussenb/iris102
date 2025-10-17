# Sesión de Debugging - 17 de octubre 2025 (tarde)

## Problema Identificado

**Root Cause:** Las Operations (MySQLOperation y PostgreSQLOperation) **no pueden conectarse via ODBC** desde el contexto de IRIS, aunque `isql` funciona correctamente desde la línea de comandos.

### Evidencia

1. **Event Log muestra errores consistentes:**
   ```
   ERROR <Ens>ErrOutConnectFailed: ODBC Connect failed for 'MySQL-Demo' / 'MySQL-Demo-Credentials' 
   with error ERROR #6022: Gateway failed. SQLConnect, with timeout of 15 failed: 
   SQLState: (HY) NativeError: [2002] Message: ????????????????????????
   ```

2. **isql funciona correctamente:**
   ```bash
   docker exec iris102 isql MySQL-Demo demo demo_pass -v
   # Conecta exitosamente
   ```

3. **Conectividad de red OK:**
   ```bash
   docker exec iris102 ping -c 2 mysql
   # 0% packet loss
   ```

4. **Configuración ODBC correcta:**
   - `/etc/odbc.ini` tiene DSN correctos
   - `/etc/odbcinst.ini` tiene drivers correctos
   - Rutas de librerías OK: `/usr/lib/x86_64-linux-gnu/odbc/libmaodbc.so`

### Intentos de Solución

1. ✅ Modificada arquitectura FileService/Process (CSVContent en mensaje)
2. ✅ Compiladas todas las clases
3. ✅ Recreadas credenciales en IRIS
4. ✅ Reiniciada Production múltiples veces
5. ✅ Probado sin Credentials en configuración (usar solo odbc.ini)
6. ❌ **Problema persiste:** 0 registros insertados

### Posibles Causas

1. **Problema de permisos:** IRIS puede no tener permisos para acceder a UnixODBC
2. **Problema de contexto de ejecución:** El adapter SQL de IRIS puede requerir configuración adicional
3. **Versión de IRIS Community:** Puede tener limitaciones en ODBC
4. **Driver Manager:** Puede haber problema entre IRIS y el driver manager de UnixODBC
5. **Timeout demasiado corto:** 15 segundos puede no ser suficiente

### Datos Técnicos

- **Contenedor IRIS:** iris102 (InterSystems IRIS Community Edition)
- **Contenedor MySQL:** iris102-mysql (MySQL 8.0)
- **Contenedor PostgreSQL:** iris102-postgres (PostgreSQL 15)
- **Driver ODBC MySQL:** MariaDB ODBC 3.1 (`libmaodbc.so`)
- **Driver ODBC PostgreSQL:** PostgreSQL Unicode (`psqlodbcw.so`)
- **UnixODBC:** 2.3.12

## Recomendaciones para Próxima Sesión

### Opción 1: Investigar Configuración de IRIS (RECOMENDADO)

1. Revisar documentación de IRIS sobre EnsLib.SQL.OutboundAdapter
2. Verificar si requiere licencia específica para ODBC
3. Buscar en InterSystems Community problemas similares
4. Intentar con Connection String directo en lugar de DSN

### Opción 2: Usar JDBC en Lugar de ODBC

1. Configurar External Language Server (Java)
2. Usar JDBC drivers en lugar de ODBC
3. Modificar Operations para usar JDBC adapter

### Opción 3: Usar SQL Gateway

1. Configurar SQL Gateway Connections desde Portal
2. Usar DSN de SQL Gateway en lugar de ODBC DSN
3. Probar conectividad desde SQL Gateway Manager

### Opción 4: Debugging Profundo

1. Habilitar tracing de ODBC: `export ODBCSYSINI=/etc; export ODBCINSTINI=odbcinst.ini`
2. Revisar logs de UnixODBC
3. Usar `strace` para ver qué está intentando hacer IRIS
4. Verificar permisos de archivos `/etc/odbc*`

## Código Funcional hasta Ahora

✅ **FileService:** Lee contenido completo del Stream  
✅ **Process:** Parsea CSV desde string en memoria  
✅ **Message Classes:** CSVContent property agregada  
✅ **Operations:** Código correcto (problema es conectividad, no código)  

## Archivos Modificados en Esta Sesión

1. `Demo.Msg.Record.cls` - Agregada propiedad `CSVContent`
2. `Demo.FileService.cls` - Lee Stream completo
3. `Demo.Process.cls` - ParseCSVFile con csvContent
4. `Demo.Production.cls` - Removidas Credentials de config
5. `BUENAS_PRACTICAS_IRIS.md` - Documento de guía completo

## Estado de Bases de Datos

- **MySQL csv_records:** 0 registros
- **PostgreSQL csv_records:** 0 registros
- **Tablas creadas:** ✅
- **ODBC DSN configurado:** ✅
- **Conectividad ODBC:** ✅ (desde isql)
- **Conectividad desde IRIS:** ❌ (ERROR #6022)

## Conclusión

La arquitectura FileService-Process está **correctamente implementada**. El bloqueador real es la **conectividad ODBC desde el contexto de IRIS**. Este es un problema de configuración/infraestructura, no de lógica de aplicación.

**Próximo paso crítico:** Investigar por qué EnsLib.SQL.OutboundAdapter no puede usar los DSN de UnixODBC que funcionan correctamente con `isql`.

---

**Fecha:** 17 de octubre de 2025, 21:46  
**Sesión de:** 3+ horas de debugging  
**Archivos copiados a contenedor:** 6 veces  
**Productions reiniciadas:** 8+ veces  
**Tests ejecutados:** 15+ archivos CSV procesados (todos fallaron en Operations)

