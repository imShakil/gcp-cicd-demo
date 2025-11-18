# Docker Compose Demo Project

A 3-tier containerized application demonstrating Docker Compose with Flask, MongoDB, and Nginx.

## Prerequisites

- Docker and Docker Compose installed
- Git (for cloning)

## Getting Started

### Option 0: Install Docker

```sh
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh ./get-docker.sh
sudo usermod -aG docker ubuntu 2>/dev/null || true

# test
sudo su - $USER
docker ps
```

### Option 1: Clone Entire Repository

```bash
git clone https://github.com/imShakil/docker-practices.git
cd docker-practices/docker-compose
```

### Option 2: Sparse Checkout (Recommended)

```bash
# Clone repository without files
git clone --no-checkout https://github.com/imShakil/docker-practices.git
cd docker-practices

# Enable sparse checkout
git sparse-checkout init --cone
git sparse-checkout set docker-compose

# Checkout files
git checkout
cd docker-compose
```

## Step-by-Step Setup

### 1. Create Environment File

```bash
# Create .env file with required variables
cat > .env << EOF
MDB_USERNAME=admin
MDB_PASSWORD=password123
MDB_NAME=moviedb
BACKEND_URI=http://backend:5000/api/
EOF
```

### 2. Build and Run

```bash
# Build and start all services
docker compose up --build

# Or run in background
docker compose up --build -d
```

### 3. Access Application

- **Frontend**: http://localhost or VM public IP
- **Database**: localhost:27017 (if needed)

### 4. Test the Application

1. Open http://localhost or http://<vm-public-ip> in browser
2. Add your name and favorite movie
3. Click "Share Movie"
4. See your movie in the shared list

![demo](./demo.png)

## Project Structure

```files
docker-compose/
├── backend/           # Flask API
│   ├── app.py
│   ├── requirements.txt
│   └── Dockerfile
├── frontend/          # Nginx + HTML
│   ├── index.html
│   ├── nginx.conf.template
│   └── Dockerfile
├── database/          # MongoDB
│   ├── init-data.js
│   └── Dockerfile
├── compose.yml        # Docker Compose config
└── .env              # Environment variables
```

## Useful Commands

```bash
# View logs
docker-compose logs -f

# Rebuild specific service
docker-compose build backend

# Stop services
docker-compose down

# Reset database (remove volumes)
docker-compose down -v

# Check running containers
docker-compose ps
```

## Troubleshooting

**Port conflicts**: Change ports in compose.yml if 80 or 27017 are in use
**Database not initializing**: Run `docker-compose down -v` then `docker-compose up --build`
**Frontend not loading**: Check nginx logs with `docker-compose logs frontend`
