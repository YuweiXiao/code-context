#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
OLLAMA_MODEL="mxbai-embed-large"
POSTGRES_USER="postgres"
POSTGRES_PASSWORD="code-context-password"
POSTGRES_DB="postgres"
POSTGRES_CONTAINER_NAME="code-context-postgres"
POSTGRES_PORT="5433"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex/}"

# Global variables for command line options
# Check if POSTGRES_URL is already set as environment variable
if [ -z "$POSTGRES_URL" ]; then
    POSTGRES_URL=""
fi
USE_EXTERNAL_POSTGRES=false

# Parse command line arguments and environment variables
parse_arguments() {
    # Check for environment variables first (for curl | bash compatibility)
    if [ -n "$POSTGRES_URL" ]; then
        log_info "Using PostgreSQL URL from environment variable: $POSTGRES_URL"
        USE_EXTERNAL_POSTGRES=true
    fi
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --postgres-url)
                POSTGRES_URL="$2"
                USE_EXTERNAL_POSTGRES=true
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Show help information
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --postgres-url URL    Specify PostgreSQL connection URL"
    echo "                       Format: postgresql://user:password@host:port/database"
    echo "                       When provided, skips Docker container installation"
    echo "                       Note: psql is optional for connection testing"
    echo "  --help, -h           Show this help message"
    echo
    echo "Environment Variables (for curl | bash compatibility):"
    echo "  POSTGRES_URL         PostgreSQL connection URL (same as --postgres-url)"
    echo
    echo "Examples:"
    echo "  $0                                    # Use Docker PostgreSQL container"
    echo "  $0 --postgres-url postgresql://user:pass@localhost:5432/mydb"
    echo "  POSTGRES_URL=postgresql://user:pass@localhost:5432/mydb $0"
    echo "  curl -fsSL <script-url> | bash -s -- --postgres-url postgresql://user:pass@localhost:5432/mydb"
    echo "  POSTGRES_URL=postgresql://user:pass@localhost:5432/mydb curl -fsSL <script-url> | bash"
    echo
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on macOS or Linux
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
    else
        log_error "Unsupported operating system: $OSTYPE"
        exit 1
    fi
    log_info "Detected OS: $OS"
}

# Install Ollama if not already installed
install_ollama() {
    log_info "Checking Ollama installation..."
    
    if command -v ollama >/dev/null 2>&1; then
        log_success "Ollama is already installed"
        return 0
    fi
    
    log_info "Installing Ollama..."
    if [[ "$OS" == "macos" ]]; then
        log_error "Ollama is not installed on macOS"
        echo "Please install Ollama manually from https://ollama.com/download/mac"
        echo "After installation, re-run this script with: ./install-mcp-setup.sh"
        exit 1
    else
        # Linux installation
        curl -fsSL https://ollama.com/install.sh | sh
    fi
    
    log_success "Ollama installed successfully"
}

# Start Ollama service if not already running
start_ollama() {
    log_info "Checking if Ollama is running..."
    
    # Check if Ollama is responding
    if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
        log_success "Ollama is already running"
        return 0
    fi
    
    log_info "Starting Ollama service..."
    if [[ "$OS" == "macos" ]]; then
        # On macOS, Ollama runs as a service
        ollama serve >/dev/null 2>&1 &
        sleep 3
    else
        # On Linux, start Ollama service
        systemctl --user start ollama || (ollama serve >/dev/null 2>&1 &)
        sleep 3
    fi
    
    # Wait for Ollama to be ready
    local max_attempts=30
    local attempt=1
    while ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; do
        if [ $attempt -ge $max_attempts ]; then
            log_error "Ollama failed to start after $max_attempts attempts"
            exit 1
        fi
        log_info "Waiting for Ollama to start... (attempt $attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done
    
    log_success "Ollama is running"
}

# Install embedding model if not already downloaded
install_embedding_model() {
    log_info "Checking if embedding model '$OLLAMA_MODEL' is installed..."
    
    # Check if model is already installed
    if ollama list | grep -q "$OLLAMA_MODEL"; then
        log_success "Embedding model '$OLLAMA_MODEL' is already installed"
        return 0
    fi
    
    log_info "Downloading embedding model '$OLLAMA_MODEL'..."
    ollama pull "$OLLAMA_MODEL"
    log_success "Embedding model '$OLLAMA_MODEL' installed successfully"
}

# Check if psql is available
check_psql() {
    if command -v psql >/dev/null 2>&1; then
        log_success "psql is available for PostgreSQL connection testing"
        return 0
    else
        log_warning "psql is not installed - PostgreSQL connection testing will be skipped"
        return 1
    fi
}

# Check if Docker is installed
check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker is not installed. Please install Docker first."
        log_info "Visit: https://docs.docker.com/get-docker/"
        echo
        log_info "Alternative: Use a cloud-hosted PostgreSQL database instead:"
        echo "  • Relyt-ONE Data Cloud: https://data.cloud/relytone"
        echo "  • Neon: https://neon.tech"
        echo
        echo "Then re-run this script with:"
        echo "  ./install-mcp-setup.sh --postgres-url postgresql://user:pass@your-cloud-host:5432/database"
        echo
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not running. Please start Docker first."
        echo
        log_info "Alternative: Use a cloud-hosted PostgreSQL database instead:"
        echo "  • Relyt-ONE Data Cloud: https://data.cloud/relytone"
        echo "  • Neon: https://neon.tech"
        echo
        echo "Then re-run this script with:"
        echo "  ./install-mcp-setup.sh --postgres-url postgresql://user:pass@your-cloud-host:5432/database"
        echo
        exit 1
    fi
    
    log_success "Docker is available"
}

# Setup PostgreSQL
setup_postgres() {
    if [ "$USE_EXTERNAL_POSTGRES" = true ]; then
        log_info "Using external PostgreSQL connection: $POSTGRES_URL"
        log_success "Skipping Docker container setup - using provided PostgreSQL URL"
        return 0
    fi
    
    log_info "Setting up PostgreSQL..."
    
    # Check if container already exists and is running
    if docker ps | grep -q "$POSTGRES_CONTAINER_NAME"; then
        log_success "PostgreSQL container '$POSTGRES_CONTAINER_NAME' is already running"
        return 0
    fi
    
    # Check if container exists but is stopped
    if docker ps -a | grep -q "$POSTGRES_CONTAINER_NAME"; then
        log_info "Starting existing PostgreSQL container..."
        docker start "$POSTGRES_CONTAINER_NAME"
        sleep 5
        log_success "PostgreSQL container started"
        return 0
    fi
    
    # Check if port is already in use and find an available port
    local available_port="$POSTGRES_PORT"
    while netstat -an | grep -q ":$available_port.*LISTEN" || docker ps | grep -q ":$available_port->"; do
        log_warning "Port $available_port is already in use, trying next port..."
        available_port=$((available_port + 1))
    done
    
    if [ "$available_port" != "$POSTGRES_PORT" ]; then
        log_info "Using port $available_port instead of $POSTGRES_PORT"
        POSTGRES_PORT="$available_port"
    fi
    
    log_info "Creating new PostgreSQL container on port $POSTGRES_PORT..."
    docker run -d \
        --name "$POSTGRES_CONTAINER_NAME" \
        -e POSTGRES_USER="$POSTGRES_USER" \
        -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
        -e POSTGRES_DB="$POSTGRES_DB" \
        -p "$POSTGRES_PORT:5432" \
        paradedb/paradedb:latest
    
    # Wait for PostgreSQL to be ready
    log_info "Waiting for PostgreSQL to be ready..."
    local max_attempts=30
    local attempt=1
    while ! docker exec "$POSTGRES_CONTAINER_NAME" pg_isready >/dev/null 2>&1; do
        if [ $attempt -ge $max_attempts ]; then
            log_error "PostgreSQL failed to start after $max_attempts attempts"
            echo
            log_info "Alternative: Use a cloud-hosted PostgreSQL database instead:"
            echo "  • Relyt-ONE Data Cloud: https://data.cloud/relytone"
            echo "  • Neon: https://neon.tech"
            echo
            echo "Then re-run this script with:"
            echo "  ./install-mcp-setup.sh --postgres-url postgresql://user:pass@your-cloud-host:5432/database"
            echo
            exit 1
        fi
        log_info "Waiting for PostgreSQL to be ready... (attempt $attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done
    
    log_success "PostgreSQL with is running"
}

# Create config directory if it doesn't exist
create_config_dir() {
    if [ ! -d "$CODEX_HOME" ]; then
        log_info "Creating config directory: $CODEX_HOME"
        mkdir -p "$CODEX_HOME"
    fi
}

# Generate and render Codex config.toml
render_config() {
    log_info "Generating Codex config.toml..."
    
    local config_file="$CODEX_HOME/config.toml"
    local postgres_connection_string
    
    if [ "$USE_EXTERNAL_POSTGRES" = true ]; then
        postgres_connection_string="$POSTGRES_URL"
    else
        postgres_connection_string="postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@localhost:$POSTGRES_PORT/$POSTGRES_DB?sslmode=disable"
    fi
    
    local mcp_server_name="claude-context"
    
    # Create new MCP server configuration
    local new_mcp_config="[mcp_servers.$mcp_server_name]
command = \"npx\"
args = [
    \"@relyt/claude-context-mcp@latest\"
]
env.EMBEDDING_PROVIDER = \"Ollama\"
env.OLLAMA_HOST = \"http://127.0.0.1:11434\"
env.EMBEDDING_MODEL = \"$OLLAMA_MODEL\"
env.VECTOR_DATABASE_PROVIDER = \"postgres\"
env.HYBRID_MODE = \"false\"
env.MCP_LOG_FILE = \"true\"
env.POSTGRES_CONNECTION_STRING = \"$postgres_connection_string\""
    
    if [ -f "$config_file" ]; then
        log_info "Existing config file found, updating MCP server configuration..."
        
        # Check if our MCP server already exists in the config
        if grep -q "\\[mcp_servers\\.$mcp_server_name\\]" "$config_file"; then
            log_info "Updating existing MCP server '$mcp_server_name' in Codex config..."
            
            # Create a temporary file for the updated config
            local temp_file=$(mktemp)
            local in_target_section=false
            local section_updated=false
            
            while IFS= read -r line; do
                # Check if we're entering our target section
                if [[ "$line" =~ ^\[mcp_servers\.$mcp_server_name\]$ ]]; then
                    in_target_section=true
                    echo "$new_mcp_config" >> "$temp_file"
                    section_updated=true
                    continue
                fi
                
                # Check if we're entering a different section
                if [[ "$line" =~ ^\[.*\]$ ]] && [ "$in_target_section" = true ]; then
                    in_target_section=false
                fi
                
                # Skip lines that belong to our target section (they'll be replaced)
                if [ "$in_target_section" = false ]; then
                    echo "$line" >> "$temp_file"
                fi
            done < "$config_file"
            
            # If section wasn't found and updated, append it
            if [ "$section_updated" = false ]; then
                echo "" >> "$temp_file"
                echo "$new_mcp_config" >> "$temp_file"
            fi
            
            mv "$temp_file" "$config_file"
        else
            log_info "Adding new MCP server '$mcp_server_name' to existing Codex config..."
            
            # Check if file ends with newline, add one if not
            if [ -s "$config_file" ] && [ "$(tail -c1 "$config_file" | wc -l)" -eq 0 ]; then
                echo "" >> "$config_file"
            fi
            
            # Add a separator comment and the new MCP server
            echo "" >> "$config_file"
            echo "$new_mcp_config" >> "$config_file"
        fi
    else
        log_info "Creating new Codex config file..."
        echo "$new_mcp_config" > "$config_file"
    fi
    
    log_success "Codex config file created/updated: $config_file"
    log_info "Configuration details:"
    echo "  - MCP Server: $mcp_server_name"
    echo "  - Embedding Provider: Ollama"
    echo "  - Ollama Host: http://127.0.0.1:11434"
    echo "  - Embedding Model: $OLLAMA_MODEL"
    echo "  - Vector Database: PostgreSQL"
    echo "  - Database Connection: $postgres_connection_string"
}

# Check if npm is installed
check_npm_installation() {
    log_info "Checking npm installation..."
    
    if command -v npm >/dev/null 2>&1; then
        log_success "✓ npm is installed"
        return 0
    else
        log_warning "✗ npm is not installed"
        return 1
    fi
}

# Install MCP package
install_mcp_package() {
    log_info "Installing MCP package..."
    
    # Check if npm is available
    if ! command -v npm >/dev/null 2>&1; then
        log_warning "npm is not available. Skipping MCP package installation."
        echo "To install the MCP package later, run: npm install -g @relyt/claude-context-mcp@latest"
        return 1
    fi
    
    # Install the MCP package globally
    log_info "Installing @relyt/claude-context-mcp package..."
    npm install -g @relyt/claude-context-mcp@latest
    
    if [ $? -eq 0 ]; then
        log_success "✓ MCP package installed successfully"
        return 0
    else
        log_error "✗ Failed to install MCP package"
        echo "You can try installing it manually later with: npm install -g @relyt/claude-context-mcp@latest"
        return 1
    fi
}

# Check if Codex is installed
check_codex_installation() {
    log_info "Checking Codex installation..."
    
    if command -v codex >/dev/null 2>&1; then
        log_success "✓ Codex is installed"
        return 0
    else
        log_warning "✗ Codex is not installed"
        return 1
    fi
}

# Test the setup
test_setup() {
    log_info "Testing the setup..."
    
    # Test Ollama
    if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
        log_success "✓ Ollama is responding"
    else
        log_error "✗ Ollama is not responding"
        return 1
    fi
    
    # Test embedding model
    if ollama list | grep -q "$OLLAMA_MODEL"; then
        log_success "✓ Embedding model '$OLLAMA_MODEL' is available"
    else
        log_error "✗ Embedding model '$OLLAMA_MODEL' is not available"
        return 1
    fi
    
    # Test PostgreSQL
    if [ "$USE_EXTERNAL_POSTGRES" = true ]; then
        # Check if psql is available for testing external PostgreSQL connection
        if command -v psql >/dev/null 2>&1; then
            # Test external PostgreSQL connection using psql
            if psql "$POSTGRES_URL" -c "SELECT 1;" >/dev/null 2>&1; then
                log_success "✓ External PostgreSQL connection successful"
            else
                log_error "✗ External PostgreSQL connection failed"
                log_info "Please verify your PostgreSQL URL: $POSTGRES_URL"
                echo
                log_info "Need a PostgreSQL database? Try these cloud providers:"
                echo "  • Relyt-ONE Data Cloud: https://data.cloud/relytone"
                echo "  • Neon: https://neon.tech"
                echo
                return 1
            fi
        else
            log_warning "⚠ psql not available - skipping external PostgreSQL connection test"
            log_info "External PostgreSQL URL configured: $POSTGRES_URL"
        fi
    else
        # Test Docker PostgreSQL container
        if docker exec "$POSTGRES_CONTAINER_NAME" pg_isready >/dev/null 2>&1; then
            log_success "✓ PostgreSQL is ready"
        else
            log_error "✗ PostgreSQL is not ready"
            return 1
        fi
        
        # Test database connection
        if docker exec "$POSTGRES_CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT 1;" >/dev/null 2>&1; then
            log_success "✓ Database connection successful"
        else
            log_error "✗ Database connection failed"
            return 1
        fi
    fi
    
    log_success "All tests passed! Setup is complete."
}

# Main installation flow
main() {
    echo "=================================================="
    echo "  MCP Setup Installation Script for Codex"
    echo "=================================================="
    echo
    
    # Parse command line arguments first
    parse_arguments "$@"
    
    detect_os
    
    # Only check Docker if we're not using external PostgreSQL
    if [ "$USE_EXTERNAL_POSTGRES" = false ]; then
        check_docker
    fi
    
    install_ollama
    start_ollama
    install_embedding_model
    
    setup_postgres
    
    # Install MCP package if npm is available
    if check_npm_installation; then
        install_mcp_package
    else
        log_warning "Skipping MCP package installation - npm not available"
    fi
    
    create_config_dir
    render_config
    
    test_setup
    
    echo
    echo "=================================================="
    log_success "Installation completed successfully!"
    echo "=================================================="
    echo

    # Check npm and Codex installation and provide appropriate instructions
    if check_codex_installation; then
        echo "Next steps:"
        echo "1. Start Codex with the following command:"
        echo "   codex"
        echo "2. The MCP server configuration has been added to: $CODEX_HOME/config.toml"
        echo "3. The MCP package (@relyt/claude-context-mcp) has been installed"
        echo "4. Codex will automatically load the MCP server on startup"
    else
        if check_npm_installation; then
            echo "Next steps:"
            echo "1. Install Codex first:"
            echo "   npm install -g @openai/codex"
            echo "   Documentation: https://developers.openai.com/codex/cli/"
            echo "2. After installing Codex, start it with:"
            echo "   codex"
            echo "3. The MCP server configuration is ready at: $CODEX_HOME/config.toml"
            echo "4. The MCP package (@relyt/claude-context-mcp) has been installed"
            echo "5. Codex will automatically load the MCP server on startup"
        else
            echo "Next steps:"
            echo "1. Install Node.js and npm first:"
            echo "   Visit: https://nodejs.org/en/download/"
            echo "2. After installing Node.js/npm, install Codex:"
            echo "   npm install -g @openai/codex"
            echo "   Documentation: https://developers.openai.com/codex/cli/"
            echo "3. Install the MCP package:"
            echo "   npm install -g @relyt/claude-context-mcp@latest"
            echo "4. Start Codex with:"
            echo "   codex"
            echo "5. The MCP server configuration is ready at: $CODEX_HOME/config.toml"
            echo "6. Codex will automatically load the MCP server on startup"
        fi
    fi

    echo
    echo "Configuration file location: $CODEX_HOME/config.toml"
    echo
    echo "Services running:"
    echo "- Ollama: http://localhost:11434"
    if [ "$USE_EXTERNAL_POSTGRES" = true ]; then
        echo "- PostgreSQL: External connection"
        echo "  - Connection URL: $POSTGRES_URL"
    else
        echo "- PostgreSQL: localhost:$POSTGRES_PORT"
        echo "  - Username: $POSTGRES_USER"
        echo "  - Password: $POSTGRES_PASSWORD"
        echo "  - Database: $POSTGRES_DB"
    fi
    echo
    echo "Note: If any installation steps failed due to missing dependencies,"
    echo "install the required software and re-run this script:"
    echo "  ./install-mcp-setup.sh"
    if [ "$USE_EXTERNAL_POSTGRES" = true ]; then
        echo
        echo "Note: For external PostgreSQL connections, 'psql' is optional but recommended"
        echo "for connection testing. If not installed, connection testing will be skipped."
    fi
    echo
}

# Run main function
main "$@"
