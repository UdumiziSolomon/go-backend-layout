#!/bin/bash

# Database Migration Script
# Usage: ./migrate.sh [up|down] [steps]

set -e  # Exit on error

# Load environment variables from .env file
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Configuration
MIGRATIONS_DIR="./migrations"
MIGRATION_TABLE="schema_migrations"

# Database Configuration
# Loads from .env file or environment variable
# Example formats:
# PostgreSQL: postgresql://user:password@host:port/database
# MySQL: mysql://user:password@host:port/database
DATABASE_URL="${DATABASE_URL:-}"

# Parse database type from URL
get_db_type() {
    if [[ $DATABASE_URL == postgresql://* ]] || [[ $DATABASE_URL == postgres://* ]]; then
        echo "postgresql"
    elif [[ $DATABASE_URL == mysql://* ]]; then
        echo "mysql"
    elif [[ $DATABASE_URL == sqlite://* ]] || [[ $DATABASE_URL == *.db ]]; then
        echo "sqlite"
    else
        echo "unknown"
    fi
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check if migrations directory exists
check_migrations_dir() {
    if [ ! -d "$MIGRATIONS_DIR" ]; then
        print_error "Migrations directory not found: $MIGRATIONS_DIR"
        exit 1
    fi
}

# Function to check database connection
check_database_url() {
    if [ -z "$DATABASE_URL" ]; then
        print_error "DATABASE_URL is not set"
        echo "Set it as an environment variable or edit the script"
        echo "Example: export DATABASE_URL='postgresql://user:password@localhost:5432/mydb'"
        exit 1
    fi
}

# Function to execute SQL based on database type
execute_sql() {
    local sql_file=$1
    local db_type=$(get_db_type)
    
    case $db_type in
        postgresql)
            psql "$DATABASE_URL" -f "$sql_file"
            ;;
        mysql)
            mysql --defaults-extra-file=<(echo -e "[client]\nuser=${DATABASE_URL#*://}" | sed 's/@.*/\n/' | sed 's/:/\npassword=/') -h "$(echo $DATABASE_URL | sed 's/.*@//' | cut -d: -f1)" "$(echo $DATABASE_URL | sed 's/.*\///')" < "$sql_file"
            ;;
        sqlite)
            sqlite3 "${DATABASE_URL#sqlite://}" < "$sql_file"
            ;;
        *)
            print_error "Unknown database type. Supported: postgresql, mysql, sqlite"
            exit 1
            ;;
    esac
}

# Function to execute SQL query
execute_query() {
    local query=$1
    local db_type=$(get_db_type)
    
    case $db_type in
        postgresql)
            psql "$DATABASE_URL" -t -c "$query"
            ;;
        mysql)
            # Simplified for query execution
            echo "$query" | mysql --defaults-extra-file=<(echo -e "[client]\nuser=${DATABASE_URL#*://}" | sed 's/@.*/\n/' | sed 's/:/\npassword=/') -h "$(echo $DATABASE_URL | sed 's/.*@//' | cut -d: -f1)" "$(echo $DATABASE_URL | sed 's/.*\///')" -s -N
            ;;
        sqlite)
            echo "$query" | sqlite3 "${DATABASE_URL#sqlite://}"
            ;;
        *)
            print_error "Unknown database type"
            exit 1
            ;;
    esac
}

# Function to initialize migration tracking table
init_migration_table() {
    print_info "Initializing migration tracking table..."
    local db_type=$(get_db_type)
    
    local create_table_sql=""
    case $db_type in
        postgresql)
            create_table_sql="CREATE TABLE IF NOT EXISTS $MIGRATION_TABLE (version VARCHAR(255) PRIMARY KEY, applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);"
            ;;
        mysql)
            create_table_sql="CREATE TABLE IF NOT EXISTS $MIGRATION_TABLE (version VARCHAR(255) PRIMARY KEY, applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);"
            ;;
        sqlite)
            create_table_sql="CREATE TABLE IF NOT EXISTS $MIGRATION_TABLE (version TEXT PRIMARY KEY, applied_at DATETIME DEFAULT CURRENT_TIMESTAMP);"
            ;;
    esac
    
    execute_query "$create_table_sql"
}

# Function to get applied migrations
get_applied_migrations() {
    execute_query "SELECT version FROM $MIGRATION_TABLE ORDER BY version;" 2>/dev/null || echo ""
}

# Function to get pending migrations
get_pending_migrations() {
    local applied_migrations=$(get_applied_migrations)
    
    for file in "$MIGRATIONS_DIR"/*.up.sql; do
        if [ -f "$file" ]; then
            version=$(basename "$file" .up.sql)
            if ! echo "$applied_migrations" | grep -q "^$version$"; then
                echo "$version"
            fi
        fi
    done | sort
}

# Function to run migration up
migrate_up() {
    local steps=${1:-all}
    
    check_migrations_dir
    check_database_url
    init_migration_table
    
    local pending=$(get_pending_migrations)
    
    if [ -z "$pending" ]; then
        print_info "No pending migrations to apply"
        return 0
    fi
    
    local count=0
    while IFS= read -r version; do
        if [ "$steps" != "all" ] && [ $count -ge $steps ]; then
            break
        fi
        
        local migration_file="$MIGRATIONS_DIR/${version}.up.sql"
        
        if [ ! -f "$migration_file" ]; then
            print_error "Migration file not found: $migration_file"
            exit 1
        fi
        
        print_info "Applying migration: $version"
        
        # Execute the migration
        execute_sql "$migration_file"
        
        # Record migration as applied
        execute_query "INSERT INTO $MIGRATION_TABLE (version) VALUES ('$version');"
        
        print_info "Migration $version applied successfully"
        ((count++))
    done <<< "$pending"
    
    print_info "Applied $count migration(s)"
}

# Function to run migration down
migrate_down() {
    local steps=${1:-1}
    
    check_migrations_dir
    check_database_url
    
    local applied=$(get_applied_migrations)
    
    if [ -z "$applied" ]; then
        print_warning "No migrations to rollback"
        return 0
    fi
    
    local count=0
    while IFS= read -r version; do
        if [ $count -ge $steps ]; then
            break
        fi
        
        local migration_file="$MIGRATIONS_DIR/${version}.down.sql"
        
        if [ ! -f "$migration_file" ]; then
            print_error "Rollback file not found: $migration_file"
            exit 1
        fi
        
        print_warning "Rolling back migration: $version"
        
        # Execute the rollback
        execute_sql "$migration_file"
        
        # Remove migration record
        execute_query "DELETE FROM $MIGRATION_TABLE WHERE version = '$version';"
        
        print_info "Migration $version rolled back successfully"
        ((count++))
    done <<< "$(echo "$applied" | sort -r)"
    
    print_warning "Rolled back $count migration(s)"
}

# Function to show migration status
show_status() {
    check_migrations_dir
    
    print_info "Migration Status:"
    echo ""
    
    local applied=$(get_applied_migrations)
    local pending=$(get_pending_migrations)
    
    echo "Applied migrations:"
    if [ -z "$applied" ]; then
        echo "  (none)"
    else
        echo "$applied" | while read -r version; do
            echo "  ✓ $version"
        done
    fi
    
    echo ""
    echo "Pending migrations:"
    if [ -z "$pending" ]; then
        echo "  (none)"
    else
        echo "$pending" | while read -r version; do
            echo "  • $version"
        done
    fi
}

# Main script logic
main() {
    local command=${1:-}
    local steps=${2:-}
    
    case "$command" in
        up)
            migrate_up "$steps"
            ;;
        down)
            migrate_down "${steps:-1}"
            ;;
        status)
            show_status
            ;;
        *)
            echo "Usage: $0 {up|down|status} [steps]"
            echo ""
            echo "Commands:"
            echo "  up [steps]     Apply pending migrations (all by default)"
            echo "  down [steps]   Rollback migrations (1 by default)"
            echo "  status         Show migration status"
            echo ""
            echo "Examples:"
            echo "  $0 up          # Apply all pending migrations"
            echo "  $0 up 1        # Apply next 1 migration"
            echo "  $0 down        # Rollback last migration"
            echo "  $0 down 3      # Rollback last 3 migrations"
            echo "  $0 status      # Show current status"
            exit 1
            ;;
    esac
}

main "$@"