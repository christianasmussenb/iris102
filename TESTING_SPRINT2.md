# Guía de Testing - Sprint 2 Completado

## Verificación de Clases Base Implementadas

### 1. Preparar Entorno

```bash
# Ir al directorio del proyecto
cd /Users/cab/VSCODE/iris102

# Copiar variables de entorno
cp env.example .env

# Iniciar servicios
docker-compose up -d

# Verificar que los contenedores están ejecutándose
docker-compose ps
```

### 2. Verificar Carga de Clases en IRIS

```bash
# Acceder al terminal de IRIS
docker exec -it iris102 iris session iris -U DEMO

# En el terminal IRIS, ejecutar:
```

```objectscript
// Verificar que el instalador funciona
do ##class(Demo.Installer).CheckStatus()

// Verificar clases de mensajes
write ##class(%Dictionary.ClassDefinition).%ExistsId("Demo.Msg.FileProcessRequest")
write ##class(%Dictionary.ClassDefinition).%ExistsId("Demo.Msg.FileProcessResponse")
write ##class(%Dictionary.ClassDefinition).%ExistsId("Demo.Msg.DBOperationRequest")
write ##class(%Dictionary.ClassDefinition).%ExistsId("Demo.Msg.DBOperationResponse")
write ##class(%Dictionary.ClassDefinition).%ExistsId("Demo.Msg.CSVRecord")

// Verificar utilidades
write ##class(%Dictionary.ClassDefinition).%ExistsId("Demo.Util.Logger")

// Verificar Production
write ##class(%Dictionary.ClassDefinition).%ExistsId("Demo.Production")

// Verificar clases de negocio
write ##class(%Dictionary.ClassDefinition).%ExistsId("Demo.FileService")
write ##class(%Dictionary.ClassDefinition).%ExistsId("Demo.Process")
write ##class(%Dictionary.ClassDefinition).%ExistsId("Demo.MySQL.Operation")
write ##class(%Dictionary.ClassDefinition).%ExistsId("Demo.Postgres.Operation")
```

### 3. Probar Utilidades de Logging

```objectscript
// Probar escritura de evento
set status = ##class(Demo.Util.Logger).WriteEvent("INFO", "TEST", "Testing logging functionality")
write $System.Status.GetErrorText(status)

// Probar escritura de archivo de log
set status = ##class(Demo.Util.Logger).WriteFileLog("TEST Testing file logging functionality")
write $System.Status.GetErrorText(status)

// Probar cálculo de hash (con archivo de muestra)
set hash = ##class(Demo.Util.Logger).HashFile("/data/samples/file1.csv")
write "Hash: ", hash

// Probar generación de nombre de archivo de salida
set outputName = ##class(Demo.Util.Logger).GenerateOutputFileName("test.csv", "ok")
write "Output filename: ", outputName

// Probar validación de CSV
set valid = ##class(Demo.Util.Logger).ValidateCSVFile("/data/samples/file1.csv", .errorMsg)
write "Valid: ", valid, " Error: ", errorMsg
```

### 4. Verificar Configuración de Production

```objectscript
// Obtener estado de Production
write ##class(Demo.Production).GetProductionStatus()

// Verificar inicialización de credenciales
do ##class(Demo.Production).InitializeCredentials()

// Verificar inicialización de paths
do ##class(Demo.Production).InitializeFilePaths()

// Verificar configuración de DB
do ##class(Demo.Production).InitializeDatabaseConnections()
```

### 5. Probar Creación de Mensajes

```objectscript
// Crear mensaje de request
set request = ##class(Demo.Msg.FileProcessRequest).%New()
set request.FilePath = "/data/IN/test.csv"
set request.FileName = "test.csv"
set request.FileSize = 1024
set request.FileHash = "abc123"
set request.DetectedAt = $ZTimeStamp
set status = request.%Save()
write "Request saved: ", $System.Status.GetErrorText(status)

// Crear mensaje de response
set response = ##class(Demo.Msg.FileProcessResponse).%New()
set response.Status = "ok"
set response.TotalRecords = 10
set response.MySQLRecordsOK = 10
set response.PostgreSQLRecordsOK = 8
set response.ProcessingStarted = $ZTimeStamp
set response.ProcessingCompleted = $ZTimeStamp
do response.CalculateDuration()
set status = response.%Save()
write "Response saved: ", $System.Status.GetErrorText(status)

// Crear registro CSV
set csvRecord = ##class(Demo.Msg.CSVRecord).%New()
set csvRecord.ExternalId = "TEST001"
set csvRecord.Name = "Test Record"
set csvRecord.Amount = 100.50
set csvRecord.OccurredAt = $ZTimeStamp
set status = csvRecord.%ValidateObject()
write "CSV Record valid: ", $System.Status.GetErrorText(status)
write "Display: ", csvRecord.%DisplayString()
```

### 6. Verificar Bases de Datos

```bash
# Verificar MySQL
docker exec -it iris102-mysql mysql -udemo -pdemo_pass demo -e "
SELECT 'MySQL Connection OK' as status;
SHOW TABLES;
SELECT COUNT(*) as initial_records FROM records;
"

# Verificar PostgreSQL (si está corriendo localmente)
docker exec -it iris102-postgres psql -U demo -d demo -c "
SELECT 'PostgreSQL Connection OK' as status;
\dt
SELECT COUNT(*) as initial_records FROM records;
"
```

### 7. Verificar Logs y Archivos

```bash
# Verificar estructura de archivos
ls -la data/
ls -la data/IN/
ls -la data/OUT/
ls -la data/LOG/
ls -la data/samples/

# Verificar contenido de archivos de muestra
cat data/samples/file1.csv
cat data/samples/file2.csv

# Verificar logs de IRIS
docker-compose logs iris | tail -20
```

## Resultados Esperados

### ✅ Éxito
- Todas las clases se compilan sin errores
- La Production se carga correctamente
- Las utilidades de logging funcionan
- Se pueden crear y validar mensajes
- Las bases de datos están conectadas
- Los archivos de muestra están disponibles

### ❌ Posibles Problemas y Soluciones

**Problema**: Clases no se compilan
```bash
# Solución: Verificar sintaxis y recompilar
docker exec -it iris102 iris session iris -U DEMO
# En IRIS: do $system.OBJ.CompileAll("ckr")
```

**Problema**: Production no inicia
```bash
# Solución: Verificar configuración
# En IRIS: do ##class(Ens.Director).StopProduction()
# En IRIS: do ##class(Ens.Director).StartProduction("Demo.Production")
```

**Problema**: No se conecta a bases de datos
```bash
# Solución: Verificar contenedores y credenciales
docker-compose ps
docker-compose logs mysql
docker-compose logs postgres
```

## Estado del Testing

- [ ] Entorno Docker iniciado correctamente
- [ ] Clases compiladas sin errores
- [ ] Utilidades de logging funcionan
- [ ] Mensajes se crean y validan correctamente
- [ ] Production se configura correctamente
- [ ] Conexiones a bases de datos OK
- [ ] Archivos de muestra disponibles

---

**Una vez completado este testing, el Sprint 2 estará oficialmente terminado y se puede proceder al Sprint 3.**