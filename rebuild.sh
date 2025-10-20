#!/bin/bash
# =============================================================================
# Script de Reconstrucción Completa - Sprint 5
# iris102 demo - Rebuild desde cero con JDBC
# Fecha: 20 Octubre 2025
# =============================================================================

set -e  # Exit on error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Función para imprimir con color
print_header() {
    echo ""
    echo -e "${CYAN}=============================================================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}=============================================================================${NC}"
    echo ""
}

print_step() {
    echo -e "${BLUE}► $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# =============================================================================
# PASO 1: Detener y limpiar todo
# =============================================================================
print_header "PASO 1: Limpieza de ambiente anterior"

print_step "Deteniendo containers actuales..."
docker compose down -v 2>/dev/null || true
docker compose -f docker-compose.yml down -v 2>/dev/null || true
docker compose -f docker-compose.new.yml down -v 2>/dev/null || true
print_success "Containers detenidos"

print_step "Eliminando containers huérfanos..."
docker container prune -f
print_success "Containers huérfanos eliminados"

print_step "Eliminando volúmenes huérfanos..."
docker volume prune -f
print_success "Volúmenes eliminados"

print_step "Eliminando imágenes viejas de iris102..."
docker image rm iris102-iris:latest 2>/dev/null || true
docker image rm iris102_iris:latest 2>/dev/null || true
docker image rm iris102-iris 2>/dev/null || true
docker image rm iris102_iris 2>/dev/null || true
print_success "Imágenes viejas eliminadas"

# =============================================================================
# PASO 2: Verificar archivos necesarios
# =============================================================================
print_header "PASO 2: Verificación de archivos"

REQUIRED_FILES=(
    "iris/Dockerfile.new"
    "iris/Installer.new.cls"
    "iris/iris.new.script"
    "docker-compose.new.yml"
    "iris/src/demo/prod/Demo.Production.cls"
)

ALL_FILES_OK=true
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        print_success "Archivo encontrado: $file"
    else
        print_error "Archivo NO encontrado: $file"
        ALL_FILES_OK=false
    fi
done

if [ "$ALL_FILES_OK" = false ]; then
    print_error "Faltan archivos requeridos. Abortando."
    exit 1
fi

print_success "Todos los archivos requeridos están presentes"

# =============================================================================
# PASO 3: Construcción de imágenes Docker
# =============================================================================
print_header "PASO 3: Construcción de imágenes Docker (sin cache)"

print_warning "Este proceso puede tomar 5-10 minutos..."
print_step "Descargando IRIS 2024.3 base image (~2GB)..."
print_step "Instalando Java 11 JDK..."
print_step "Descargando JDBC drivers (MySQL + PostgreSQL)..."
echo ""

if docker compose -f docker-compose.new.yml build --no-cache; then
    print_success "Imágenes construidas exitosamente"
else
    print_error "Error en la construcción de imágenes"
    exit 1
fi

# =============================================================================
# PASO 4: Iniciar servicios
# =============================================================================
print_header "PASO 4: Iniciando servicios"

print_step "Iniciando MySQL y PostgreSQL..."
docker compose -f docker-compose.new.yml up -d mysql postgres

print_step "Esperando a que las bases de datos estén listas..."
sleep 10

print_step "Verificando MySQL..."
RETRIES=30
COUNT=0
until docker exec iris102-mysql mysqladmin ping -h localhost -u root -proot --silent 2>/dev/null; do
    COUNT=$((COUNT+1))
    if [ $COUNT -ge $RETRIES ]; then
        print_error "MySQL no está respondiendo después de $RETRIES intentos"
        exit 1
    fi
    echo "   Intento $COUNT/$RETRIES..."
    sleep 2
done
print_success "MySQL está listo"

print_step "Verificando PostgreSQL..."
COUNT=0
until docker exec iris102-postgres pg_isready -U demo -d demo 2>/dev/null; do
    COUNT=$((COUNT+1))
    if [ $COUNT -ge $RETRIES ]; then
        print_error "PostgreSQL no está respondiendo después de $RETRIES intentos"
        exit 1
    fi
    echo "   Intento $COUNT/$RETRIES..."
    sleep 2
done
print_success "PostgreSQL está listo"

print_step "Iniciando IRIS..."
docker compose -f docker-compose.new.yml up -d iris

print_warning "Esperando inicialización de IRIS (~60 segundos)..."
sleep 60

# =============================================================================
# PASO 5: Verificar estado de los servicios
# =============================================================================
print_header "PASO 5: Verificación de servicios"

print_step "Estado de containers:"
docker compose -f docker-compose.new.yml ps

echo ""
print_step "Verificando logs de IRIS (últimas 50 líneas)..."
echo ""
docker compose -f docker-compose.new.yml logs --tail=50 iris

# =============================================================================
# PASO 6: Validaciones
# =============================================================================
print_header "PASO 6: Validaciones"

print_step "Verificando JDBC drivers en filesystem..."
if docker exec iris102 ls -lh /opt/irisapp/jdbc/ | grep -q "mysql-connector"; then
    print_success "MySQL JDBC driver encontrado"
else
    print_warning "MySQL JDBC driver NO encontrado"
fi

if docker exec iris102 ls -lh /opt/irisapp/jdbc/ | grep -q "postgresql"; then
    print_success "PostgreSQL JDBC driver encontrado"
else
    print_warning "PostgreSQL JDBC driver NO encontrado"
fi

print_step "Verificando Java installation..."
if docker exec iris102 java -version 2>&1 | grep -q "11"; then
    print_success "Java 11 instalado correctamente"
else
    print_warning "Java 11 NO encontrado o versión incorrecta"
fi

print_step "Verificando MySQL database..."
if docker exec iris102-mysql mysql -u demo -pdemo -e "USE demo; SHOW TABLES;" 2>/dev/null | grep -q "csv_records"; then
    print_success "Tabla csv_records existe en MySQL"
else
    print_warning "Tabla csv_records NO encontrada en MySQL"
fi

print_step "Verificando PostgreSQL database..."
if docker exec iris102-postgres psql -U demo -d demo -c "\dt" 2>/dev/null | grep -q "csv_records"; then
    print_success "Tabla csv_records existe en PostgreSQL"
else
    print_warning "Tabla csv_records NO encontrada en PostgreSQL"
fi

# =============================================================================
# RESUMEN FINAL
# =============================================================================
print_header "RESUMEN DE RECONSTRUCCIÓN"

echo -e "${GREEN}✓ Limpieza completada${NC}"
echo -e "${GREEN}✓ Imágenes Docker construidas${NC}"
echo -e "${GREEN}✓ Servicios iniciados${NC}"
echo -e "${GREEN}✓ Validaciones ejecutadas${NC}"

echo ""
print_header "ACCESOS"

echo -e "${CYAN}IRIS Management Portal:${NC}"
echo "  URL:      http://localhost:52773/csp/sys/UtilHome.csp"
echo "  Usuario:  SuperUser"
echo "  Password: SYS"
echo ""

echo -e "${CYAN}IRIS Production:${NC}"
echo "  URL:      http://localhost:52773/csp/demo/EnsPortal.ProductionConfig.zen"
echo ""

echo -e "${CYAN}MySQL:${NC}"
echo "  Host:     localhost:3306"
echo "  Database: demo"
echo "  Usuario:  demo"
echo "  Password: demo"
echo ""

echo -e "${CYAN}PostgreSQL:${NC}"
echo "  Host:     localhost:5432"
echo "  Database: demo"
echo "  Usuario:  demo"
echo "  Password: demo"
echo ""

print_header "PRÓXIMOS PASOS"

echo "1. Acceder al Management Portal y verificar que la Production esté corriendo"
echo "2. Implementar Demo.MySQL.JDBCOperation"
echo "3. Implementar Demo.Postgres.JDBCOperation"
echo "4. Probar con test_basic.csv"
echo ""

print_header "COMANDOS ÚTILES"

echo "Ver logs en tiempo real:"
echo "  docker compose -f docker-compose.new.yml logs -f iris"
echo ""

echo "Acceder a terminal IRIS:"
echo "  docker exec -it iris102 iris session iris -U DEMO"
echo ""

echo "Detener servicios:"
echo "  docker compose -f docker-compose.new.yml down"
echo ""

echo "Reiniciar solo IRIS:"
echo "  docker compose -f docker-compose.new.yml restart iris"
echo ""

print_success "Reconstrucción completada exitosamente!"
echo ""
