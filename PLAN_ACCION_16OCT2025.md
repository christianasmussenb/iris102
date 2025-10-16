# Plan de Acción - IRIS102 Sistema Ingesta CSV
## Fecha: 16 de octubre de 2025

---

## 📊 RESUMEN EJECUTIVO

### Estado Actual
- **Infraestructura**: ✅ 100% operativa (4 contenedores activos)
- **Pipeline CSV**: ✅ 90% completo (detección, parseo, logging, archivado)
- **Conectividad ODBC**: ✅ Verificada (DSN MySQL-Demo y PostgreSQL-Demo OK)
- **Conectividad JDBC**: ⚠️ Drivers listos, conexiones SQL Gateway NO creadas
- **Validación DB**: ❌ Inserciones reales sin probar end-to-end

### Bloqueadores Críticos
1. **SQL Gateway JDBC**: Conexiones no existen en Portal (bloqueante para inserciones)
2. **Prueba end-to-end**: Nunca se ejecutó flujo completo con CSV real
3. **Tablas verificadas**: Estructura OK pero sin datos de prueba

---

## 🎯 PLAN DE ACCIÓN PRIORIZADO

### **FASE 1: PREPARACIÓN** ✅ COMPLETADA (16/10/2025)

#### Tarea 1.1: Archivos CSV de prueba ✅
- **Estado**: Completado
- **Archivos creados**:
  - `data/samples/test_basic.csv` (5 registros válidos)
  - `data/samples/test_small.csv` (3 registros válidos)
  - `data/samples/test_with_errors.csv` (4 registros con errores)

#### Tarea 1.2: Verificación de tablas DB ✅
- **MySQL**: Tabla `csv_records` existe con estructura correcta
  - Campos: id, csv_id, name, age, city, source_file, file_hash, created_at
- **PostgreSQL**: Tabla `csv_records` existe (demo_data NO existe pero csv_records sí)
  - Estructura idéntica a MySQL
  - ⚠️ Nota: El código de Demo.Postgres.Operation menciona `demo_data` pero la tabla real es `csv_records`

---

### **FASE 2: CONFIGURACIÓN SQL GATEWAY** 🔴 CRÍTICO - PENDIENTE

#### Tarea 2.1: Verificar Object Gateways en IRIS ⏳
**Prioridad**: ALTA  
**Tiempo estimado**: 10 min  
**Acciones**:
```bash
# Opción A: Verificar via terminal
docker exec -i iris102 iris session IRIS -U "%SYS" << 'EOF'
Set sc = ##class(Config.Gateways).Get("JDBC-MySQL", .gw)
If $SYSTEM.Status.IsOK(sc) {
    Write "JDBC-MySQL encontrado:",!
    ZWrite gw
} Else {
    Write "JDBC-MySQL NO encontrado",!
}
EOF

# Opción B: Re-ejecutar Installer para crear gateways
docker exec -i iris102 iris session IRIS -U USER << 'EOF'
Do ##class(Demo.Installer).SetupSQLGateway()
EOF
```

**Criterio de éxito**: 
- Gateways `JDBC-MySQL` y `JDBC-PostgreSQL` visibles en Portal
- ClassPath apuntando a `/opt/irisapp/jdbc/*.jar`
- JavaHome configurado correctamente

#### Tarea 2.2: Crear conexiones SQL Gateway en Portal ⏳
**Prioridad**: ALTA  
**Tiempo estimado**: 15 min  
**Acciones**:
1. Acceder a Portal IRIS: http://localhost:52773/csp/sys/
2. Navegar: System Administration > Configuration > SQL Gateway Connections
3. Crear conexión MySQL:
   - **Connection Name**: MySQL-Demo
   - **Server**: JDBC-MySQL
   - **Database/Schema**: demo
   - **Username**: demo
   - **Password**: demo_pass
4. Crear conexión PostgreSQL:
   - **Connection Name**: PostgreSQL-Demo
   - **Server**: JDBC-PostgreSQL
   - **Database/Schema**: demo
   - **Username**: demo
   - **Password**: demo_pass
5. **Test Connection** para ambas

**Criterio de éxito**: 
- Ambas conexiones con estado "Connected"
- Test query `SELECT 1` exitoso

---

### **FASE 3: VALIDACIÓN END-TO-END** 🟡 ALTA PRIORIDAD

#### Tarea 3.1: Preparar entorno de pruebas ⏳
**Prioridad**: ALTA  
**Tiempo estimado**: 5 min  
**Acciones**:
```bash
# Limpiar datos previos (opcional)
docker exec -i iris102-mysql mysql -udemo -pdemo_pass demo -e "DELETE FROM csv_records;"
docker exec -i iris102-postgres psql -U demo -d demo -c "DELETE FROM csv_records;"

# Verificar Production activa
docker exec iris102 iris session IRIS -U USER -s "write ##class(Ens.Director).IsProductionRunning()"
# Debe retornar: 1
```

#### Tarea 3.2: Ejecutar prueba con CSV básico ⏳
**Prioridad**: ALTA  
**Tiempo estimado**: 10 min  
**Acciones**:
```bash
# 1. Copiar archivo de prueba
cp data/samples/test_basic.csv data/IN/test_001.csv

# 2. Esperar 5-10 segundos (FileService call interval)
sleep 10

# 3. Verificar archivo archivado
ls -la data/OUT/ | grep test_001

# 4. Revisar logs
tail -50 data/LOG/event_$(date +%Y%m%d).log

# 5. Verificar Event Log en Portal
# http://localhost:52773/csp/healthshare/user/EnsPortal.EventLog.zen
```

**Criterio de éxito**:
- Archivo movido de IN/ a OUT/ con sufijo de estado
- Log muestra procesamiento exitoso
- Event Log sin errores críticos

#### Tarea 3.3: Validar inserciones en bases de datos ⏳
**Prioridad**: ALTA  
**Tiempo estimado**: 5 min  
**Acciones**:
```bash
# Verificar registros en MySQL
docker exec -i iris102-mysql mysql -udemo -pdemo_pass demo << 'EOF'
SELECT COUNT(*) as total FROM csv_records;
SELECT csv_id, name, age, city, source_file FROM csv_records ORDER BY id DESC LIMIT 5;
EOF

# Verificar registros en PostgreSQL
docker exec -i iris102-postgres psql -U demo -d demo << 'EOF'
SELECT COUNT(*) AS total FROM csv_records;
SELECT csv_id, name, age, city, source_file FROM csv_records ORDER BY id DESC LIMIT 5;
EOF
```

**Criterio de éxito**:
- MySQL: 5 registros insertados (test_basic.csv)
- PostgreSQL: 5 registros insertados
- Campos coinciden con CSV original

---

### **FASE 4: CORRECCIONES Y AJUSTES** 🟢 MEDIA PRIORIDAD

#### Tarea 4.1: Alinear nombres de tablas PostgreSQL ⏳
**Problema detectado**: Demo.Postgres.Operation.cls menciona tabla `demo_data` pero existe `csv_records`

**Acciones**:
- Opción A: Renombrar referencias en código a `csv_records`
- Opción B: Crear tabla `demo_data` y migrar lógica

**Recomendación**: Opción A (menor impacto)

#### Tarea 4.2: Manejo de errores en CSV ⏳
**Acciones**:
```bash
# Probar con archivo con errores
cp data/samples/test_with_errors.csv data/IN/test_errors.csv

# Verificar manejo:
# - Registros válidos insertados
# - Registros inválidos logueados
# - Estado "partial" en archivo OUT
```

---

### **FASE 5: DOCUMENTACIÓN** 🟢 MEDIA PRIORIDAD

#### Tarea 5.1: Guía SQL Gateway en README ⏳
**Contenido a agregar**:
- Cómo crear conexiones JDBC manualmente
- Cómo re-ejecutar Installer para automatizar
- Troubleshooting común:
  - "ClassPath not found"
  - "Java Gateway not started"
  - "Connection timeout"
  - Diferencias ODBC vs JDBC

#### Tarea 5.2: Scripts de validación ⏳
**Crear**: `scripts/validate_db.sh`
```bash
#!/bin/bash
# Script de validación de inserciones
echo "=== MySQL ==="
docker exec -i iris102-mysql mysql -udemo -pdemo_pass demo -e "SELECT COUNT(*) FROM csv_records;"

echo "=== PostgreSQL ==="
docker exec -i iris102-postgres psql -U demo -d demo -c "SELECT COUNT(*) FROM csv_records;"
```

---

## 📈 MÉTRICAS DE ÉXITO

### Criterios de Aceptación Sprint 5
- [ ] SQL Gateway JDBC configurado y validado
- [ ] Al menos 3 archivos CSV procesados exitosamente
- [ ] Inserciones verificadas en MySQL y PostgreSQL
- [ ] Logs sin errores críticos
- [ ] Documentación actualizada con troubleshooting

### KPIs Objetivo
- **Tasa de éxito**: >95% de archivos procesados correctamente
- **Tiempo de procesamiento**: <10s por archivo de 100 registros
- **Disponibilidad**: Production activa 24/7 sin reintentos
- **Cobertura logs**: 100% de operaciones registradas

---

## 🚨 RIESGOS IDENTIFICADOS

1. **SQL Gateway no funciona con JDBC**: 
   - Mitigación: ODBC ya verificado como fallback
   
2. **Permisos de escritura en tablas**:
   - Mitigación: Usuario `demo` tiene permisos completos
   
3. **Timeout de conexión en Production**:
   - Mitigación: Ajustar `RetryCount` y `RetryInterval` en Operations

---

## 📅 CRONOGRAMA PROPUESTO

| Fase | Tareas | Tiempo | Inicio | Fin |
|------|--------|--------|--------|-----|
| 1 | Preparación | 15 min | ✅ | ✅ |
| 2 | SQL Gateway | 25 min | Hoy | Hoy |
| 3 | Validación E2E | 20 min | Hoy | Hoy |
| 4 | Correcciones | 30 min | Mañana | Mañana |
| 5 | Documentación | 45 min | Mañana | Mañana |

**Total estimado**: ~2h 15min trabajo efectivo

---

## 🎯 PRÓXIMOS PASOS INMEDIATOS (HOY)

### Paso 1: Re-ejecutar Installer para crear SQL Gateway
```bash
docker exec -i iris102 iris session IRIS -U USER << 'EOF'
Do ##class(Demo.Installer).SetupSQLGateway()
EOF
```

### Paso 2: Verificar gateways en Portal
- URL: http://localhost:52773/csp/sys/
- Ruta: System Administration > Configuration > Connectivity > External Language Servers
- Buscar: JDBC-MySQL y JDBC-PostgreSQL

### Paso 3: Ejecutar prueba básica
```bash
cp data/samples/test_basic.csv data/IN/test_$(date +%H%M%S).csv
sleep 10
ls -la data/OUT/
tail -50 data/LOG/event_$(date +%Y%m%d).log
```

---

## 📞 CONTACTO Y SOPORTE

**Documentación clave**:
- README.md: Instalación y uso
- avances.md: Estado del proyecto
- PLAN_CONTINUACION.md: Roadmap técnico

**URLs importantes**:
- Portal IRIS: http://localhost:52773/csp/sys/
- Adminer: http://localhost:8080
- Production: http://localhost:52773/csp/user/EnsPortal.ProductionConfig.zen

---

**Última actualización**: 16 de octubre de 2025  
**Próxima revisión**: Tras completar FASE 3
