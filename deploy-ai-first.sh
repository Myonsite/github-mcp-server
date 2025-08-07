#!/bin/bash

# AI-First Company Docker Deployment Script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
DOCKER_COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"

# Function to print colored output
print_header() {
    echo -e "\n${PURPLE}🚀 $1${NC}"
    echo "$(printf '=%.0s' {1..50})"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_step() {
    echo -e "${CYAN}▶️  $1${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    print_success "Docker is installed"
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    print_success "Docker Compose is available"
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    print_success "Docker is running"
    
    # Check available disk space (at least 2GB)
    available_space=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$available_space" -lt 2 ]; then
        print_warning "Low disk space. At least 2GB recommended."
    else
        print_success "Sufficient disk space available"
    fi
}

# Function to setup environment
setup_environment() {
    print_header "Setting Up Environment"
    
    if [ ! -f "$ENV_FILE" ]; then
        print_step "Creating environment file from template..."
        
        # Get current user
        CURRENT_USER=$(whoami)
        
        # Create .env file from template
        cat > "$ENV_FILE" << EOF
# AI-First Company Docker Environment Configuration
# Generated on $(date)

# GitHub API Configuration
GITHUB_PERSONAL_ACCESS_TOKEN=your_github_pat_here
GITHUB_TOKEN=your_github_token_here

# PostgreSQL Configuration
POSTGRES_PASSWORD=ai_first_secure_password_$(date +%s)

# Web Search Configuration (Optional)
BRAVE_SEARCH_API_KEY=your_brave_search_api_key_here

# System Configuration
USER=${CURRENT_USER}
LOG_LEVEL=info

# Optional: Additional API Keys
OPENAI_API_KEY=your_openai_api_key_here
ANTHROPIC_API_KEY=your_anthropic_api_key_here
EOF
        
        print_success "Environment file created: $ENV_FILE"
        print_warning "Please edit $ENV_FILE and add your GitHub Personal Access Token"
        print_info "You can generate a token at: https://github.com/settings/tokens"
        
        # Ask if user wants to edit now
        read -p "Do you want to edit the environment file now? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ${EDITOR:-nano} "$ENV_FILE"
        fi
    else
        print_success "Environment file already exists: $ENV_FILE"
    fi
}

# Function to create necessary directories
create_directories() {
    print_header "Creating Directory Structure"
    
    directories=(
        "data/sqlite"
        "data/filesystem"
        "data/memory"
        "logs"
        "mcp-servers/sqlite"
        "mcp-servers/filesystem"
        "mcp-servers/memory"
        "mcp-servers/postgres"
        "mcp-servers/web"
    )
    
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            print_success "Created directory: $dir"
        else
            print_info "Directory already exists: $dir"
        fi
    done
    
    # Set proper permissions
    chmod -R 755 data/ logs/ mcp-servers/ 2>/dev/null || true
    print_success "Set directory permissions"
}

# Function to pull Docker images
pull_docker_images() {
    print_header "Pulling Docker Images"
    
    images=(
        "ghcr.io/github/github-mcp-server:latest"
        "node:18-alpine"
        "postgres:15-alpine"
    )
    
    for image in "${images[@]}"; do
        print_step "Pulling $image..."
        if docker pull "$image"; then
            print_success "Pulled $image"
        else
            print_warning "Failed to pull $image (continuing anyway)"
        fi
    done
}

# Function to deploy services
deploy_services() {
    print_header "Deploying AI-First Services"
    
    print_step "Starting Docker Compose services..."
    
    # Use docker-compose or docker compose based on availability
    if command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker-compose"
    else
        DOCKER_COMPOSE_CMD="docker compose"
    fi
    
    # Start services
    if $DOCKER_COMPOSE_CMD --env-file "$ENV_FILE" -f "$DOCKER_COMPOSE_FILE" up -d; then
        print_success "Services started successfully"
    else
        print_error "Failed to start services"
        exit 1
    fi
    
    # Wait for services to be healthy
    print_step "Waiting for services to be ready..."
    sleep 30
    
    # Check service status
    print_step "Checking service status..."
    $DOCKER_COMPOSE_CMD --env-file "$ENV_FILE" -f "$DOCKER_COMPOSE_FILE" ps
}

# Function to run health checks
run_health_checks() {
    print_header "Running Health Checks"
    
    services=(
        "http://localhost:3000|Dashboard"
        "http://localhost:8080|Monitoring"
        "http://localhost:8001|GitHub MCP"
        "http://localhost:5432|PostgreSQL"
    )
    
    for service in "${services[@]}"; do
        IFS='|' read -r url name <<< "$service"
        print_step "Checking $name..."
        
        if [[ "$url" == *":5432"* ]]; then
            # Special check for PostgreSQL
            if docker exec ai-first-postgres-db pg_isready -U ai_first_user &> /dev/null; then
                print_success "$name is healthy"
            else
                print_warning "$name is not ready yet"
            fi
        else
            # HTTP health check
            if curl -f -s "$url/api/health" &> /dev/null || curl -f -s "$url" &> /dev/null; then
                print_success "$name is healthy"
            else
                print_warning "$name is not ready yet"
            fi
        fi
    done
}

# Function to display access information
display_access_info() {
    print_header "Access Information"
    
    echo -e "${CYAN}🌐 Web Interfaces:${NC}"
    echo -e "  📊 AI-First Dashboard:    http://localhost:3000"
    echo -e "  📈 Monitoring Dashboard:  http://localhost:8080"
    echo ""
    echo -e "${CYAN}🔗 MCP Server Endpoints:${NC}"
    echo -e "  🐙 GitHub MCP:            http://localhost:8001"
    echo -e "  🗄️  SQLite MCP:            http://localhost:8002"
    echo -e "  📁 Filesystem MCP:        http://localhost:8003"
    echo -e "  🧠 Memory MCP:            http://localhost:8004"
    echo -e "  🐘 PostgreSQL MCP:        http://localhost:8005"
    echo -e "  🌐 Web Search MCP:        http://localhost:8006"
    echo ""
    echo -e "${CYAN}🗄️  Database Access:${NC}"
    echo -e "  🐘 PostgreSQL:            localhost:5432"
    echo -e "     Database: ai_first"
    echo -e "     Username: ai_first_user"
    echo -e "     Password: (check .env file)"
    echo ""
    echo -e "${CYAN}📋 Management Commands:${NC}"
    echo -e "  📊 View logs:              ./manage-ai-first.sh logs"
    echo -e "  🔄 Restart services:       ./manage-ai-first.sh restart"
    echo -e "  🛑 Stop services:          ./manage-ai-first.sh stop"
    echo -e "  📈 Show status:            ./manage-ai-first.sh status"
}

# Function to create management script
create_management_script() {
    print_header "Creating Management Script"
    
    cat > "manage-ai-first.sh" << 'EOF'
#!/bin/bash

# AI-First Company Management Script
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
DOCKER_COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Determine Docker Compose command
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
else
    DOCKER_COMPOSE_CMD="docker compose"
fi

show_usage() {
    echo "AI-First Company Management Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start     Start all services"
    echo "  stop      Stop all services"
    echo "  restart   Restart all services"
    echo "  status    Show service status"
    echo "  logs      Show service logs"
    echo "  health    Run health checks"
    echo "  update    Update and restart services"
    echo "  clean     Stop and remove all containers"
    echo "  backup    Backup database and data"
    echo "  help      Show this help message"
}

start_services() {
    echo -e "${BLUE}🚀 Starting AI-First services...${NC}"
    $DOCKER_COMPOSE_CMD --env-file "$ENV_FILE" -f "$DOCKER_COMPOSE_FILE" up -d
    echo -e "${GREEN}✅ Services started${NC}"
}

stop_services() {
    echo -e "${YELLOW}🛑 Stopping AI-First services...${NC}"
    $DOCKER_COMPOSE_CMD --env-file "$ENV_FILE" -f "$DOCKER_COMPOSE_FILE" down
    echo -e "${GREEN}✅ Services stopped${NC}"
}

restart_services() {
    echo -e "${BLUE}🔄 Restarting AI-First services...${NC}"
    $DOCKER_COMPOSE_CMD --env-file "$ENV_FILE" -f "$DOCKER_COMPOSE_FILE" restart
    echo -e "${GREEN}✅ Services restarted${NC}"
}

show_status() {
    echo -e "${BLUE}📊 Service Status:${NC}"
    $DOCKER_COMPOSE_CMD --env-file "$ENV_FILE" -f "$DOCKER_COMPOSE_FILE" ps
    
    echo -e "\n${BLUE}🔗 Quick Access:${NC}"
    echo "Dashboard:    http://localhost:3000"
    echo "Monitoring:   http://localhost:8080"
}

show_logs() {
    if [ -n "$2" ]; then
        echo -e "${BLUE}📝 Logs for $2:${NC}"
        $DOCKER_COMPOSE_CMD --env-file "$ENV_FILE" -f "$DOCKER_COMPOSE_FILE" logs -f "$2"
    else
        echo -e "${BLUE}📝 All service logs (last 100 lines):${NC}"
        $DOCKER_COMPOSE_CMD --env-file "$ENV_FILE" -f "$DOCKER_COMPOSE_FILE" logs --tail=100
    fi
}

run_health_check() {
    echo -e "${BLUE}🏥 Running health checks...${NC}"
    
    services=(
        "http://localhost:3000|Dashboard"
        "http://localhost:8080|Monitoring"
        "http://localhost:8001|GitHub MCP"
    )
    
    for service in "${services[@]}"; do
        IFS='|' read -r url name <<< "$service"
        if curl -f -s "$url" &> /dev/null; then
            echo -e "${GREEN}✅ $name is healthy${NC}"
        else
            echo -e "${RED}❌ $name is not responding${NC}"
        fi
    done
}

update_services() {
    echo -e "${BLUE}📦 Updating services...${NC}"
    docker pull ghcr.io/github/github-mcp-server:latest
    $DOCKER_COMPOSE_CMD --env-file "$ENV_FILE" -f "$DOCKER_COMPOSE_FILE" up -d --force-recreate
    echo -e "${GREEN}✅ Services updated${NC}"
}

clean_services() {
    echo -e "${YELLOW}🧹 Cleaning up containers and volumes...${NC}"
    read -p "This will remove all containers and data. Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        $DOCKER_COMPOSE_CMD --env-file "$ENV_FILE" -f "$DOCKER_COMPOSE_FILE" down -v --remove-orphans
        docker system prune -f
        echo -e "${GREEN}✅ Cleanup completed${NC}"
    else
        echo -e "${YELLOW}Cleanup cancelled${NC}"
    fi
}

backup_data() {
    echo -e "${BLUE}💾 Creating backup...${NC}"
    backup_dir="backups/backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup database
    docker exec ai-first-postgres-db pg_dump -U ai_first_user ai_first > "$backup_dir/database.sql"
    
    # Backup data directories
    cp -r data/ "$backup_dir/"
    
    echo -e "${GREEN}✅ Backup created: $backup_dir${NC}"
}

case "$1" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs "$@"
        ;;
    health)
        run_health_check
        ;;
    update)
        update_services
        ;;
    clean)
        clean_services
        ;;
    backup)
        backup_data
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo ""
        show_usage
        exit 1
        ;;
esac
EOF
    
    chmod +x "manage-ai-first.sh"
    print_success "Management script created: ./manage-ai-first.sh"
}

# Main deployment function
main() {
    print_header "AI-First Company Docker Deployment"
    print_info "This script will deploy your complete AI-first toolkit locally using Docker"
    echo ""
    
    # Ask for confirmation
    read -p "Do you want to proceed with the deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Deployment cancelled"
        exit 0
    fi
    
    # Run deployment steps
    check_prerequisites
    setup_environment
    create_directories
    create_management_script
    pull_docker_images
    deploy_services
    
    # Wait a bit for services to start
    print_step "Waiting for services to initialize..."
    sleep 45
    
    run_health_checks
    display_access_info
    
    print_header "🎉 Deployment Complete!"
    print_success "Your AI-First Company toolkit is now running locally!"
    print_info "Visit http://localhost:3000 to access the main dashboard"
    print_info "Use ./manage-ai-first.sh to manage your deployment"
    echo ""
    print_warning "Remember to configure your GitHub Personal Access Token in the .env file"
}

# Run main function
main "$@" 