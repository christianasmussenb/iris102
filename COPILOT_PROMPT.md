Quiero un **proyecto de demostración** llamado `iris102` que use **InterSystems IRIS Interoperability** para orquestar una ingesta de archivos CSV desde el **file system**, con este flujo:

1. Un **Business Service** observa una carpeta `./data/IN/` y cuando aparece `file1.csv` (o cualquier `file*.csv`) dispara el proceso.
2. El **Business Process** parsea el CSV y envía los registros a dos **Business Operations**:

   * **OpMySQL**: inserta cada fila en una **BD MySQL local** (en Docker).
   * **OpPostgres**: inserta cada fila en una **BD Postgres externa** (p. ej. servicio administrado “nano” en AWS/GCP/Azure).
3. Al terminar (éxito total o parcial), el **Service** mueve el archivo a `./data/OUT/` con **renombrado**: `<nombre>__YYYYMMDD_HHMMSS__<status>.csv` (status=`ok` si todo bien; `partial` si hubo fallas parciales; `error` si no se insertó nada).
4. Generar **logs detallados** del proceso y sus pasos:

   * a) **Event Log** estándar de IRIS (Ens.EventLog / Ens.Alert).
   * b) **Archivo de log** legible en `./data/LOG/` por día: `ingest_YYYYMMDD.log`, con timestamps por línea y resumen por archivo procesado.
5. El sistema debe ser **idempotente** y **tolerante a fallas**:

   * Evitar duplicados por **hash/CRC** del archivo + `filename`.
   * Reintentos con backoff en los Business Operations ante errores transitorios.
   * Si falla Postgres pero MySQL fue ok, marcar `status=partial`, loggear las filas fallidas y continuar.

#### Tecnologías y convenciones

* **IRIS Interoperability** (Productions).
* Lenguaje: **ObjectScript** para Service/Process/Operations + configuración de Production.
* Adaptadores:

  * **Inbound**: `EnsLib.File.InboundAdapter` (watcher de carpeta).
  * **Outbound SQL**: `EnsLib.SQL.OutboundAdapter` (uno con DSN/connection para MySQL y otro para Postgres).
* Parsing CSV: usar utilidades nativas o un parser simple que soporte **cabeceras** y **delimitador “,”** con **“** para quoted fields**.
* **Variables de entorno** para credenciales y conexiones. Nunca hardcodear passwords.
* **Docker Compose** para levantar IRIS y MySQL local. Postgres quedará externo, pero incluir opción de un servicio Postgres local **solo para pruebas**.

#### Estructura del repo (generar archivos y carpetas)

```
iris-file-ingest-demo/
  docker-compose.yml
  iris/
    Dockerfile
    Installer.cls          # carga de la Production y seeds
    src/
      demo/
        prod/
          Demo.Production.cls
          Demo.FileService.cls
          Demo.BPL.Process.bpl         # BPL opcional (o BusinessProcess en .cls)
          Demo.MySQL.Operation.cls
          Demo.Postgres.Operation.cls
          Demo.Msg.Record.cls          # request/response messages
          Demo.Util.Logger.cls         # helper para file logs + hash
  sql/
    mysql_init.sql         # DDL tabla destino (MySQL)
    postgres_init.sql      # DDL tabla destino (Postgres)
  env.example              # variables de entorno (copiar a .env)
  data/
    IN/                    # carpeta de entrada
    OUT/                   # carpeta de salida
    LOG/                   # logs por día
    samples/
      file1.csv            # muestra con cabeceras
  README.md
  COPILOT_TASKS.md         # lista de tareas/criterios de aceptación
```

#### Clases y responsabilidades (ObjectScript)

* `Demo.Production`

  * Define:

    * `FileService` (Demo.FileService) con `EnsLib.File.InboundAdapter` apuntando a `./data/IN/`, `FileSpec="file*.csv"`, `WorkDir=./data/WIP/` (si usas uno).
    * `Process` (Demo.BPL.Process o Demo.Process) que recibe ruta/stream CSV, **parsea**, valida y envía lotes a las operaciones.
    * `OpMySQL` (Demo.MySQL.Operation) con `EnsLib.SQL.OutboundAdapter` (conexión MySQL).
    * `OpPostgres` (Demo.Postgres.Operation) con `EnsLib.SQL.OutboundAdapter` (conexión Postgres).
  * Maneja **Settings** leídos desde **ENV** (rutas, DSNs, retries).

* `Demo.FileService`

  * `OnProcessInput()` toma el archivo nuevo, calcula **hash/CRC**, verifica duplicado, crea un **request** con metadatos: filename, fullpath, size, hash, timestamp.
  * Llama al `Process`.
  * Según el **response** final, mueve/renombra a `./data/OUT/`.
  * Loggea inicio/fin a **Event Log** y al archivo `./data/LOG/ingest_YYYYMMDD.log`.

* `Demo.BPL.Process` (o clase BusinessProcess)

  * **Parsea CSV** (stream seguro, manejo de UTF-8).
  * Valida tipos (ej., `id` INT, `date` ISO, `amount` DECIMAL(12,2), etc.).
  * Envía **batches** a `OpMySQL` y `OpPostgres`.
  * Si MySQL ok y Postgres falla en N filas → `status=partial`.
  * Construye respuesta con conteos: `rows_total`, `rows_ok_mysql`, `rows_ok_pg`, `rows_failed_mysql`, `rows_failed_pg`.

* `Demo.MySQL.Operation` / `Demo.Postgres.Operation`

  * Preparar `INSERT ...` parametrizado (evitar SQL injection).
  * **Upsert** opcional por clave natural (p.ej. `(ExternalId, Date)`).
  * Retries con backoff exponencial (p.ej. 3 intentos, 0.5s, 2s, 5s).
  * Errores: devolver lista de filas que no se pudieron insertar con motivo.

* `Demo.Msg.Record`

  * Definir mensajes Request/Response y, si hace falta, un `Record` para cada fila.

* `Demo.Util.Logger`

  * Helpers: `WriteEvent(level, text)`, `WriteFileLog(line)`, `NowISO()`, `HashFile(path)`.

#### Bases de datos y DDL (crear scripts)

* **Tabla destino ejemplo** (misma forma en MySQL y Postgres):

```sql
CREATE TABLE records (
  id SERIAL PRIMARY KEY,                -- en MySQL usar INT AUTO_INCREMENT
  external_id VARCHAR(64) NOT NULL,
  name        VARCHAR(200) NOT NULL,
  amount      DECIMAL(12,2) NOT NULL,
  occurred_at TIMESTAMP NOT NULL,
  source_file VARCHAR(255) NOT NULL,
  file_hash   VARCHAR(64)  NOT NULL
);
CREATE UNIQUE INDEX uq_records_extid_date ON records (external_id, occurred_at);
```

* Asegurar que **tipos** y **índices** existen en ambos motores.

#### Docker & conexiones

* `docker-compose.yml` con servicios:

  * `iris`: usa imagen IRIS Community for Health (o IRIS Community), expone Portal y SuperServer, monta `./iris/src`.
  * `mysql`: imagen oficial MySQL 8, con `sql/mysql_init.sql` como init.
  * `adminer`: opcional para explorar MySQL.
* Variables de entorno (en `env.example`, copiar a `.env`):

  * `IN_DIR=./data/IN`
  * `OUT_DIR=./data/OUT`
  * `LOG_DIR=./data/LOG`
  * `MYSQL_HOST=mysql`
  * `MYSQL_DB=demo`
  * `MYSQL_USER=demo`
  * `MYSQL_PASSWORD=demo_pass`
  * `PG_HOST=<host-externo>`
  * `PG_DB=<db>`
  * `PG_USER=<user>`
  * `PG_PASSWORD=<password>`
  * `PG_SSLMODE=require` (si aplica)
* **IRIS** debe poder conectarse a:

  * MySQL local (ODBC o JDBC; preferir JDBC con driver MySQL 8).
  * Postgres externo (JDBC con SSL si corresponde).
    Incluir la **configuración del Adapter** (DSN/JDBC URL, usuario, password) en la Production (usando **Settings** y leyendo de ENV).

#### Manejo de archivos

* El Service no debe bloquear el archivo antes de que esté completamente escrito (usar polling con `FileAccessTimeout`).
* Tras procesar, mover a `./data/OUT/<nombre>__YYYYMMDD_HHMMSS__<status>.csv`.
* Si el archivo es duplicado (hash ya visto), mover a OUT con `__duplicate`.

#### Logging y métricas

* Cada archivo procesado debe dejar:

  * Resumen en `ingest_YYYYMMDD.log`:
    `2025-10-14T12:00:01Z START file1.csv size=... hash=...`
    `...`
    `2025-10-14T12:00:05Z END file1.csv status=partial rows_total=100 rows_ok_mysql=100 rows_ok_pg=92 rows_failed_pg=8`
  * Entradas en Event Log IRIS por hitos y errores.
* Exponer **contadores** en Production (settings o trace) para auditoría.

#### Datos de prueba

* `data/samples/file1.csv` con cabeceras:

```
external_id,name,amount,occurred_at
C001,Cliente Uno,1234.56,2025-10-14T11:30:00Z
C002,Cliente Dos,789.00,2025-10-14T11:45:00Z
```

#### Criterios de aceptación (automatizar en `COPILOT_TASKS.md`)

1. Al copiar `file1.csv` a `./data/IN/`, el Service lo detecta, procesa y lo mueve a `./data/OUT/` renombrado con timestamp y status.
2. Registros insertados en **MySQL** y **Postgres** (si Postgres falla, status `partial` y se loggea).
3. Logs creados en `./data/LOG/ingest_YYYYMMDD.log` con líneas START/END y métricas.
4. Reintentos implementados en las Operations y sin duplicados si el mismo archivo entra dos veces.
5. Toda la configuración sensible viene desde `.env`.
6. `docker-compose up` levanta IRIS + MySQL; con Postgres externo configurable por ENV.
7. README con pasos: `docker-compose up`, configurar connections en IRIS si aplica, prueba con el sample, verificación en MySQL/Postgres, dónde ver logs/eventos.

> Genera **todo el código**, archivos, clases ObjectScript, BPL (si decides usarlo), SQL de inicialización, Dockerfiles y README con instrucciones claras. Asegúrate de que el proyecto sea reproducible end-to-end.
