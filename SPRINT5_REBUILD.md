# Sprint 5 - Reconstrucción Completa desde Cero

## 📋 Objetivo

Reconstruir completamente la infraestructura Docker partiendo desde cero:
1. **IRIS 2024.3** como base
2. **MySQL 8.0** y **PostgreSQL 15** 
3. **Java 11 JDK** para JDBC
4. **JDBC Drivers oficiales** (MySQL Connector/J 8.0.33 + PostgreSQL JDBC 42.6.0)
5. **Eliminar toda configuración ODBC** (legacy)

---

## 🏗️ Arquitectura Nueva

```
┌─────────────────────────────────────────────────────────────┐
│                     IRIS 2024.3 Container                    │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │           Java Gateway (Port 55556)                 │    │
│  │  Classpath: mysql-connector-j + postgresql JDBC    │    │
│  └────────────────────────────────────────────────────┘    │
│                           ↑                                  │
│                           │                                  │
│  ┌────────────────────────────────────────────────────┐    │
│  │  Demo.MySQL.JDBCOperation    (JDBC)                │    │
│  │  Demo.Postgres.JDBCOperation (JDBC)                │    │
│  └────────────────────────────────────────────────────┘    │
│                           ↑                                  │
│  ┌────────────────────────────────────────────────────┐    │
│  │           Demo.Process (CSV Parser)                 │    │
│  └────────────────────────────────────────────────────┘    │
│                           ↑                                  │
│  ┌────────────────────────────────────────────────────┐    │
│  │      Demo.FileService (Stream Reader)               │    │
│  │      Monitors: /data/IN/                            │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                           │
          ┌────────────────┴────────────────┐
          ↓                                  ↓
┌──────────────────┐            ┌──────────────────┐
│  MySQL 8.0       │            │  PostgreSQL 15   │
│  Port: 3306      │            │  Port: 5432      │
│  DB: demo        │            │  DB: demo        │
│  Table:          │            │  Table:          │
│   csv_records    │            │   csv_records    │
└──────────────────┘            └──────────────────┘
```

---

## 📁 Archivos Nuevos Creados

### 1. **Dockerfile.new**
- Base: `intersystemsdc/irishealth-community:2024.3`
- Instalación de Java 11 JDK
- Descarga de JDBC drivers desde Maven Central y PostgreSQL.org
- Configuración de `JAVA_HOME` y `JDBC_CLASSPATH`
- **Sin ODBC** (completamente eliminado)

### 2. **docker-compose.new.yml**
- 3 servicios: `iris`, `mysql`, `postgres`
- Health checks configurados
- Orden de inicio: MySQL/PostgreSQL → IRIS
- Volúmenes persistentes para las bases de datos
- Red bridge: `iris102_network`

### 3. **Installer.new.cls**
- Importación de fuentes
- Compilación de clases
- **Configuración de Java Gateway** (nuevo)
- **Prueba de conectividad JDBC** (nuevo)
- Inicio de Production

### 4. **iris.new.script**
- Script bash de inicialización
- Creación de namespace DEMO
- Habilitación de Interoperability
- Ejecución del Installer
- Manejo de errores mejorado

---

## 🚀 Proceso de Construcción

### Paso 1: Detener y limpiar todo
```bash
# Detener containers actuales
docker-compose down -v

# Eliminar containers huérfanos
docker container prune -f

# Eliminar volúmenes huérfanos
docker volume prune -f

# Eliminar imágenes viejas (opcional)
docker image rm iris102-iris:latest
docker image rm iris102_iris:latest
```

### Paso 2: Construcción limpia
```bash
# Construir con el nuevo docker-compose
docker-compose -f docker-compose.new.yml build --no-cache

# Esto toma ~5-10 minutos:
# - Descarga IRIS 2024.3 base image (~2GB)
# - Instala Java 11 JDK
# - Descarga MySQL JDBC driver (2.4 MB)
# - Descarga PostgreSQL JDBC driver (1.1 MB)
```

### Paso 3: Iniciar servicios
```bash
# Iniciar todos los servicios
docker-compose -f docker-compose.new.yml up -d

# Ver logs en tiempo real
docker-compose -f docker-compose.new.yml logs -f

# Esperar a que IRIS termine inicialización (~60 segundos)
```

### Paso 4: Verificar estado
```bash
# Verificar que todos los containers están corriendo
docker-compose -f docker-compose.new.yml ps

# Debería mostrar:
# iris102          running   52773->52773, 1972->1972
# iris102-mysql    running   3306->3306
# iris102-postgres running   5432->5432
```

### Paso 5: Validar instalación
```bash
# Acceder al Management Portal
# http://localhost:52773/csp/sys/UtilHome.csp
# Usuario: SuperUser
# Password: SYS

# Verificar Production está corriendo:
# http://localhost:52773/csp/demo/EnsPortal.ProductionConfig.zen
```

---

## 🔍 Validaciones Post-Instalación

### 1. Verificar Java Gateway
```objectscript
// En Terminal IRIS (namespace DEMO)
ZN "DEMO"

// Crear conexión al gateway
Set gateway = ##class(%Net.Remote.Gateway).%New()
Set status = gateway.%Connect("127.0.0.1", 55556, $NAMESPACE)
Write "Gateway Status: ", $SYSTEM.Status.GetErrorText(status),!

// Verificar classpath
Set class = gateway.%New("java.lang.Class")
Do class.forName("com.mysql.cj.jdbc.Driver")
Write "MySQL Driver: OK",!

Do class.forName("org.postgresql.Driver")  
Write "PostgreSQL Driver: OK",!

Do gateway.%Disconnect()
```

### 2. Verificar JDBC Drivers en filesystem
```bash
# Desde el host
docker exec -it iris102 ls -lh /opt/irisapp/jdbc/

# Debería mostrar:
# mysql-connector-j-8.0.33.jar    (~2.4 MB)
# postgresql-42.6.0.jar           (~1.1 MB)
```

### 3. Verificar bases de datos
```bash
# MySQL
docker exec -it iris102-mysql mysql -u demo -pdemo -e "SHOW DATABASES; USE demo; SHOW TABLES;"

# PostgreSQL
docker exec -it iris102-postgres psql -U demo -d demo -c "\dt"
```

---

## 📊 Diferencias ODBC vs JDBC

| Aspecto | ODBC (Sprint 4) ❌ | JDBC (Sprint 5) ✅ |
|---------|-------------------|-------------------|
| **Driver Installation** | `apt-get install odbc-*` | Descarga directa de `.jar` |
| **Configuration** | `/etc/odbc.ini`, `/etc/odbcinst.ini` | `CLASSPATH` environment variable |
| **IRIS Adapter** | `EnsLib.SQL.OutboundAdapter` | `%Net.Remote.Gateway` |
| **Connection String** | DSN name | JDBC URL |
| **Debugging** | Difícil (mensajes corruptos) | Fácil (stack traces Java) |
| **Estabilidad** | ERROR #6022 irresolvable | Probado y estable |
| **Documentación** | Escasa para IRIS | Abundante |

---

## 🎯 Próximos Pasos

Una vez validada la infraestructura:

1. **Crear Demo.MySQL.JDBCOperation**
   - Extender de `Ens.BusinessOperation`
   - Usar `%Net.Remote.Gateway` para conectar
   - JDBC URL: `jdbc:mysql://mysql:3306/demo`

2. **Crear Demo.Postgres.JDBCOperation**
   - Similar a MySQL
   - JDBC URL: `jdbc:postgresql://postgres:5432/demo`

3. **Actualizar Demo.Production**
   - Reemplazar Operations ODBC con JDBC
   - Configurar Java Gateway connection

4. **Testing**
   - Copiar `test_basic.csv` a `/data/IN/`
   - Verificar Visual Trace
   - Confirmar registros en ambas DB

---

## 📝 Comandos Útiles

```bash
# Ver logs de IRIS en tiempo real
docker-compose -f docker-compose.new.yml logs -f iris

# Acceder a terminal IRIS
docker exec -it iris102 iris session iris -U DEMO

# Reiniciar solo IRIS (sin perder datos de DB)
docker-compose -f docker-compose.new.yml restart iris

# Detener todo
docker-compose -f docker-compose.new.yml down

# Detener todo y borrar volúmenes (RESET COMPLETO)
docker-compose -f docker-compose.new.yml down -v
```

---

## ⚠️ Troubleshooting

### Error: "Cannot connect to Java Gateway"
```bash
# Verificar que el gateway está configurado
docker exec -it iris102 iris session iris -U DEMO

# En el terminal IRIS:
Set gw = ##class(%Net.Remote.Service).%OpenId("JavaGateway")
Write gw.Port  // Debería ser 55556
Do gw.%Save()
```

### Error: "ClassNotFoundException" para JDBC drivers
```bash
# Verificar que los JARs existen
docker exec -it iris102 ls -lh /opt/irisapp/jdbc/

# Verificar CLASSPATH
docker exec -it iris102 env | grep CLASSPATH
```

### Error: "MySQL/PostgreSQL not reachable"
```bash
# Verificar red Docker
docker network inspect iris102_network

# Debería mostrar iris102, iris102-mysql, iris102-postgres en la misma red
```

---

**Fecha:** 20 Octubre 2025  
**Sprint:** 5  
**Objetivo:** Migración completa de ODBC a JDBC
