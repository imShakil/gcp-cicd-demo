#!/bin/bash

# Deployment script for GCP VM
# This script pulls Docker images from Container Registry and deploys using docker-compose

set -e
set -x

# Parameters
PROJECT_ID=${1:-}
IMAGE_TAG=${2:-latest}
DB_NAME=${3:-}
DB_USERNAME=${4:-}
DB_PASSWORD=${5:-}

if [ -z "$PROJECT_ID" ]; then
    echo "Error: PROJECT_ID not provided"
    exit 1
fi

echo "Starting deployment..."
echo "Project ID: $PROJECT_ID"
echo "Image Tag: $IMAGE_TAG"

# Create deployment directory
DEPLOY_DIR="/opt/demo-app"
mkdir -p $DEPLOY_DIR
cd $DEPLOY_DIR

# Configure Docker authentication for private Container Registry images
# If service account key exists, use it to authenticate
if [ -f /tmp/vm-key.json ]; then
    echo "Authenticating Docker with service account key..."
    cat /tmp/vm-key.json | docker login -u _json_key --password-stdin https://gcr.io
elif [ -f ~/.docker/config.json ]; then
    echo "Docker already authenticated"
else
    echo "Warning: No authentication found. Images must be public or authentication must be pre-configured."
fi

# Create .env file with environment variables
cat > .env << EOF
MDB_USERNAME=$DB_USERNAME
MDB_PASSWORD=$DB_PASSWORD
MDB_NAME=$DB_NAME
BACKEND_URI=http://backend:5000/api/
GCR_PROJECT_ID=$PROJECT_ID
IMAGE_TAG=$IMAGE_TAG
EOF

# Create docker-compose.yml with GCR images
cat > docker-compose.yml << EOF
services:
  database:
    image: gcr.io/$PROJECT_ID/demo-db:$IMAGE_TAG
    container_name: db
    restart: always
    environment:
      MONGO_INITDB_ROOT_USERNAME: \${MDB_USERNAME}
      MONGO_INITDB_ROOT_PASSWORD: \${MDB_PASSWORD}
      MONGO_INITDB_DATABASE: \${MDB_NAME}
    networks:
      - backend-network
    volumes:
      - mongo-data:/data/db
    ports:
      - 27017:27017

  backend:
    image: gcr.io/$PROJECT_ID/demo-api:$IMAGE_TAG
    container_name: api
    restart: always
    environment:
      - MONGO_URI=mongodb://\${MDB_USERNAME}:\${MDB_PASSWORD}@database:27017/\${MDB_NAME}?authSource=admin
    depends_on:
      - database
    networks:
      - backend-network
      - frontend-network

  frontend:
    image: gcr.io/$PROJECT_ID/demo-ui:$IMAGE_TAG
    container_name: ui
    restart: always
    environment:
      - BACKEND_URI=\${BACKEND_URI}
    depends_on:
      - backend
    networks:
      - frontend-network
    ports:
      - 80:80

networks:
  backend-network:
  frontend-network:

volumes:
  mongo-data:
EOF

# Stop and remove existing containers and images
echo "Cleaning up existing deployment..."
docker compose down --volumes --remove-orphans 2>/dev/null || true
docker system prune -f

# Pull latest images
echo "Pulling Docker images from Container Registry..."
docker pull gcr.io/$PROJECT_ID/demo-db:$IMAGE_TAG
docker pull gcr.io/$PROJECT_ID/demo-api:$IMAGE_TAG
docker pull gcr.io/$PROJECT_ID/demo-ui:$IMAGE_TAG

# Start new containers
echo "Starting containers..."
docker compose up -d

# Wait for services to be ready
echo "Waiting for services to be ready..."
sleep 10

# Check container status
echo "Container status:"
docker compose ps

echo "Deployment completed successfully!"
echo "Application should be accessible at http://$(hostname -I | awk '{print $1}')"
