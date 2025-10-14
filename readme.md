# IRIS102 - Sistema de Ingesta de Archivos CSV

Proyecto de demostración que utiliza **InterSystems IRIS Interoperability** para orquestar la ingesta de archivos CSV desde el sistema de archivos hacia bases de datos MySQL y PostgreSQL.

## Características Principales

- 🔄 **Procesamiento automático** de archivos CSV desde carpeta monitoreada
- 🏗️ **Arquitectura Interoperability** con Business Service, Process y Operations  
- 🐘 **Dual database**: MySQL local + PostgreSQL externo
- 📝 **Logging detallado** con Event Log y archivos por día
- 🔒 **Tolerancia a fallas** con reintentos y detección de duplicados
- 🐳 **Containerizado** con Docker Compose

## Arquitectura del Sistema

```
./data/IN/ → FileService → Process → [MySQL Operation, PostgreSQL Operation] → ./data/OUT/
                ↓
          Event Log + ./data/LOG/
```

### Componentes

1. **Demo.FileService**: Monitorea `./data/IN/` y detecta archivos `file*.csv`
2. **Demo.Process**: Parsea CSV y coordina envío a bases de datos
3. **Demo.MySQL.Operation**: Inserta datos en MySQL local
4. **Demo.Postgres.Operation**: Inserta datos en PostgreSQL externo
5. **Demo.Util.Logger**: Manejo de logs y cálculo de hash para duplicados

## Requisitos

- Docker y Docker Compose
- 4GB RAM disponible para contenedores
- Puertos disponibles: 1972, 52773, 3306, 5432, 8080

## Instalación Rápida

### 1. Clonar y Configurar

```bash
git clone <repo-url> iris102
cd iris102

# Copiar variables de entorno
cp env.example .env

# Editar .env con las credenciales de PostgreSQL externo
nano .env
```

### 2. Configurar PostgreSQL Externo

Edita el archivo `.env` y configura las variables de PostgreSQL:

```env
# Para AWS RDS
PG_HOST=mydb.abc123.us-east-1.rds.amazonaws.com
PG_PORT=5432
PG_DB=mydatabase
PG_USER=myuser
PG_PASSWORD=mypassword
PG_SSLMODE=require
```

### 3. Iniciar Servicios

```bash
# Iniciar IRIS y MySQL
docker-compose up -d

# Ver logs de inicialización
docker-compose logs -f iris

# Para pruebas locales (incluye PostgreSQL local)
docker-compose --profile local-testing up -d
```

### 4. Verificar Instalación

```bash
# Verificar que todos los contenedores están ejecutándose
docker-compose ps

# Acceder al Portal de IRIS
open http://localhost:52773/csp/sys/UtilHome.csp
# Usuario: SuperUser, Password: SYS

# Verificar MySQL con Adminer
open http://localhost:8080
# Server: mysql, Username: demo, Password: demo_pass, Database: demo
```

## Uso del Sistema

### Procesar un Archivo CSV

1. **Copiar archivo a la carpeta de entrada**:
```bash
cp data/samples/file1.csv data/IN/
```

2. **Monitorear el procesamiento**:
```bash
# Ver logs en tiempo real
tail -f data/LOG/ingest_$(date +%Y%m%d).log

# Ver logs de IRIS
docker-compose logs -f iris
```

3. **Verificar resultados**:
```bash
# Verificar archivo procesado
ls -la data/OUT/

# Verificar datos en MySQL
docker exec -it iris102-mysql mysql -udemo -pdemo_pass demo -e "SELECT COUNT(*) FROM records;"

# Verificar datos en PostgreSQL (si es local)
docker exec -it iris102-postgres psql -U demo -d demo -c "SELECT COUNT(*) FROM records;"
```

## Estructura del Proyecto

```
iris102/
├── docker-compose.yml          # Orchestración de contenedores
├── env.example                 # Template de variables de entorno
├── iris/                       # Configuración de IRIS
│   ├── Dockerfile             
│   ├── iris.script            # Script de inicialización
│   ├── Installer.cls          # Instalador automático
│   └── src/demo/prod/         # Clases ObjectScript
├── sql/                       # Scripts de inicialización SQL
│   ├── mysql_init.sql
│   └── postgres_init.sql
├── data/                      # Directorio de datos
│   ├── IN/                    # Archivos CSV de entrada
│   ├── OUT/                   # Archivos procesados
│   ├── LOG/                   # Logs diarios
│   └── samples/               # Archivos de ejemplo
└── avances.md                 # Seguimiento del proyecto
```

## Configuración Avanzada

### Variables de Entorno Importantes

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `PG_HOST` | Host de PostgreSQL externo | `mydb.region.rds.amazonaws.com` |
| `PG_DB` | Nombre de la base de datos | `production_db` |
| `PG_USER` | Usuario de PostgreSQL | `app_user` |
| `PG_PASSWORD` | Password de PostgreSQL | `secure_password` |
| `PG_SSLMODE` | Modo SSL | `require` |

### Formato de Archivo CSV

Los archivos deben tener el formato:

```csv
external_id,name,amount,occurred_at
C001,Cliente Uno,1234.56,2025-10-14T11:30:00Z
C002,Cliente Dos,789.00,2025-10-14T11:45:00Z
```

- **external_id**: Identificador único del cliente
- **name**: Nombre del cliente
- **amount**: Monto (formato decimal)
- **occurred_at**: Fecha/hora en formato ISO 8601

## Troubleshooting

### Problema: IRIS no inicia
```bash
# Verificar logs
docker-compose logs iris

# Recrear contenedor
docker-compose down
docker-compose up -d iris
```

### Problema: No se conecta a PostgreSQL
```bash
# Verificar conectividad desde IRIS
docker exec -it iris102 iris session iris -U DEMO

# En el terminal IRIS:
# zw ##class(Demo.Postgres.Operation).TestConnection()
```

### Problema: Archivos no se procesan
```bash
# Verificar Production
docker exec -it iris102 iris session iris -U DEMO

# En el terminal IRIS:
# write ##class(Ens.Director).GetProductionStatus()
```

## Estado del Desarrollo

- ✅ **Sprint 1**: Infraestructura base completada
- 🔄 **Sprint 2**: Clases base de IRIS (en progreso)
- ⏳ **Sprint 3**: Business Service
- ⏳ **Sprint 4**: Business Process  
- ⏳ **Sprint 5**: Business Operations
- ⏳ **Sprint 6**: Integración y testing
- ⏳ **Sprint 7**: Documentación final

Ver progreso detallado en [avances.md](avances.md).

## Soporte

Para problemas o dudas:
1. Verificar logs en `data/LOG/`
2. Revisar Event Log en IRIS Portal
3. Consultar documentación de troubleshooting arriba

---

**Versión**: 1.0.0  
**Última actualización**: 14 de octubre de 2025