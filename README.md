# MCP Setup Installation Script for Codex

This script automates the installation and configuration of the Claude Context MCP (Model Context Protocol) server for Codex, including Ollama embedding models and PostgreSQL database setup.

## Features

- **Automatic Ollama Installation**: Installs and configures Ollama with embedding models
- **Flexible PostgreSQL Setup**: Supports both Docker containers and external PostgreSQL connections
- **MCP Package Installation**: Installs the `@relyt/claude-context-mcp` package
- **Codex Configuration**: Automatically generates and updates Codex configuration files
- **Cross-Platform**: Supports macOS and Linux
- **Comprehensive Testing**: Validates all components after installation

## Prerequisites

### Required Dependencies
- **Node.js and npm**: For installing MCP packages
- **Docker**: Required only when using Docker PostgreSQL container (default behavior)

### Optional Dependencies
- **psql**: PostgreSQL client for testing external database connections (optional but recommended)

## Installation Methods

### Method 1: Direct Download and Execute

```bash
# Download and run with default settings (Docker PostgreSQL)
curl -fsSL https://raw.githubusercontent.com/YuweiXiao/code-context/refs/heads/main/install-mcp-setup.sh | bash

# Download and run with external PostgreSQL
curl -fsSL https://raw.githubusercontent.com/YuweiXiao/code-context/refs/heads/main/install-mcp-setup.sh | bash -s -- --postgres-url postgresql://user:pass@host:port/database
```

### Method 2: Manual Download

```bash
# Download the script
curl -O https://raw.githubusercontent.com/YuweiXiao/code-context/refs/heads/main/install-mcp-setup.sh

# Make it executable
chmod +x install-mcp-setup.sh

# Run with options
./install-mcp-setup.sh [OPTIONS]
```

## Usage

### Command Line Options

```bash
./install-mcp-setup.sh [OPTIONS]
```

**Options:**
- `--postgres-url URL`: Specify PostgreSQL connection URL
  - Format: `postgresql://user:password@host:port/database`
  - When provided, skips Docker container installation
  - Note: psql is optional for connection testing
- `--help, -h`: Show help message

### Examples

```bash
# Use Docker PostgreSQL container (default)
./install-mcp-setup.sh

# Use external PostgreSQL connection
./install-mcp-setup.sh --postgres-url postgresql://user:pass@localhost:5432/mydb

# Show help
./install-mcp-setup.sh --help
```

### Environment Variables (for curl | bash compatibility)

For scenarios where you can't pass command-line arguments (like `curl | bash`), you can use environment variables:

```bash
# Using external PostgreSQL with environment variable
export POSTGRES_URL="postgresql://user:pass@localhost:5432/mydb"
curl -fsSL https://raw.githubusercontent.com/YuweiXiao/code-context/refs/heads/main/install-mcp-setup.sh | bash
```

**Supported Environment Variables:**
- `POSTGRES_URL`: PostgreSQL connection URL (equivalent to `--postgres-url`)

## What the Script Does

### 1. System Detection
- Detects operating system (macOS/Linux)
- Checks for required dependencies

### 2. Ollama Setup
- Installs Ollama if not present
- Starts Ollama service
- Downloads embedding model (`mxbai-embed-large`)

### 3. PostgreSQL Configuration
- **Docker Mode (default)**: Creates and starts PostgreSQL container with ParadeDB
- **External Mode**: Uses provided PostgreSQL connection URL

### 4. MCP Package Installation
- Installs `@relyt/claude-context-mcp` globally via npm

### 5. Codex Configuration
- Creates/updates Codex configuration file (`~/.codex/config.toml`)
- Configures MCP server with appropriate settings

### 6. Testing and Validation
- Tests Ollama connectivity
- Validates embedding model availability
- Tests PostgreSQL connection (if psql is available)
- Reports installation status

## Configuration Details

The script generates a Codex configuration with the following settings:

```toml
[mcp_servers.claude-context-local]
command = "npx"
args = ["@relyt/claude-context-mcp@latest"]
env.EMBEDDING_PROVIDER = "Ollama"
env.OLLAMA_HOST = "http://127.0.0.1:11434"
env.EMBEDDING_MODEL = "mxbai-embed-large"
env.VECTOR_DATABASE_PROVIDER = "postgres"
env.HYBRID_MODE = "false"
env.POSTGRES_CONNECTION_STRING = "postgresql://..."
```

## Default Settings

- **Ollama Model**: `mxbai-embed-large`
- **PostgreSQL Container**: `code-context-postgres`
- **PostgreSQL Port**: `5433` (auto-adjusted if in use)
- **PostgreSQL User**: `postgres`
- **PostgreSQL Password**: `code-context-password`
- **PostgreSQL Database**: `postgres`
- **Codex Config Directory**: `~/.codex/`

## Troubleshooting

### Common Issues

1. **Docker not running**
   ```bash
   # Start Docker Desktop or Docker service
   # On Linux: sudo systemctl start docker
   ```

2. **Port conflicts**
   - The script automatically finds available ports
   - Default PostgreSQL port is 5433 to avoid conflicts

3. **psql not found**
   - This is optional and won't prevent installation
   - Install PostgreSQL client tools if you want connection testing

4. **npm/npm not installed**
   - Install Node.js from https://nodejs.org/
   - The script will skip MCP package installation if npm is unavailable

5. **PostgreSQL setup failures**
   - If Docker PostgreSQL fails, consider using cloud-hosted databases:
     - **Relytone Data Cloud**: https://data.cloud/relytone
     - **Neon.tech**: https://neon.tech
   - Then re-run with: `./install-mcp-setup.sh --postgres-url postgresql://user:pass@host:port/database`

### Manual Steps After Installation

If the script fails at any step, you can **Install missing dependencies** and re-run the script
