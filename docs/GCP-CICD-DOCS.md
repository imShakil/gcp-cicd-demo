# Google Cloud CI/CD Demo - Cloud Build Automation

This guide explains how to automate deployment of the Docker Compose application to a GCP VM using Cloud Build.

## Architecture Overview

```flow
GitHub Repository
       ↓
   Cloud Build (triggered on push)
       ↓
   Build Docker Images
       ↓
   Push to Container Registry (GCR)
       ↓
   Deploy to GCP VM (via SSH)
       ↓
   Run docker-compose on VM
```

## Prerequisites

1. **GCP Project** with billing enabled
2. **GCP VM Instance** (Compute Engine) with:
   - Docker and Docker Compose installed
   - Service account with appropriate permissions
   - SSH access configured
3. **GitHub Repository** connected to Cloud Build
4. **gcloud CLI** installed locally (for initial setup)

## Step 1: Set Up GCP VM

### 1.1 Create a Compute Engine VM Instance

```bash
gcloud compute instances create demo-vm \
  --zone=us-central1-a \
  --machine-type=e2-medium \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --scopes=cloud-platform \
  --metadata-from-file startup-script=vm-startup.sh
```

### 1.2 Install Docker on VM (if not using startup script)

SSH into your VM:

```bash
gcloud compute ssh demo-vm --zone=us-central1-a
```

Then run:

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh ./get-docker.sh
sudo usermod -aG docker $USER
sudo su - $USER
docker ps
```

**Note:** Only Docker and Docker Compose are needed on the VM. `gcloud` CLI is not required since Cloud Build handles all GCP authentication.

### 1.3 Configure Service Account for Cloud Build

Create a service account:

```bash
gcloud iam service-accounts create cloud-build-deployer \
  --display-name="Cloud Build Deployer"
```

Grant necessary permissions:

```bash
# Allow Cloud Build to use Compute Engine
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member=serviceAccount:cloud-build-deployer@PROJECT_ID.iam.gserviceaccount.com \
  --role=roles/compute.instanceAdmin.v1

# Allow Cloud Build to use Service Accounts
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member=serviceAccount:cloud-build-deployer@PROJECT_ID.iam.gserviceaccount.com \
  --role=roles/iam.serviceAccountUser

# Allow Cloud Build to access Container Registry
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member=serviceAccount:cloud-build-deployer@PROJECT_ID.iam.gserviceaccount.com \
  --role=roles/storage.admin
```

## Step 2: Configure Cloud Build

### 2.1 Connect GitHub Repository

1. Go to [Cloud Build Console](https://console.cloud.google.com/cloud-build)
2. Click **Connect Repository**
3. Select **GitHub** as source
4. Authorize and select your repository
5. Click **Connect**

### 2.2 Create Build Trigger

1. In Cloud Build Console, go to **Triggers**
2. Click **Create Trigger**
3. Configure:
   - **Name**: `demo-app-deploy`
   - **Event**: Push to a branch
   - **Repository**: Select your connected repo
   - **Branch**: `^main$` (or your branch)
   - **Build Configuration**: Cloud Build configuration file
   - **Location**: `cloudbuild.yaml`
4. Click **Create**

### 2.3 Update cloudbuild.yaml Substitutions

Edit `cloudbuild.yaml` and update the substitutions section with your VM details:

```yaml
substitutions:
  _VM_NAME: 'demo-vm'           # Your VM instance name
  _VM_ZONE: 'us-central1-a'     # Your VM zone
```

## Step 3: Cloud Build Pipeline Explanation

The `cloudbuild.yaml` file contains the following steps:

### Step 1-3: Build Docker Images

- Builds database, backend, and frontend images
- Tags with both `$SHORT_SHA` (commit hash) and `latest`

### Step 4-6: Push to Container Registry

- Pushes all three images to `gcr.io/$PROJECT_ID/`

### Step 7: Deploy to VM

- Copies `deploy.sh` script to VM via SSH
- Executes deployment script with project ID and image tag

## Step 4: Deployment Script (deploy.sh)

The `deploy.sh` script runs on the VM and:

1. Authenticates Docker with GCR
2. Creates `.env` file with environment variables
3. Generates `docker-compose.yml` with GCR image references
4. Pulls latest images from Container Registry
5. Stops existing containers
6. Starts new containers with `docker compose up -d`
7. Verifies deployment

## Step 5: Trigger Deployment

### Option A: Automatic (Recommended)

Push changes to your GitHub repository:

```bash
git add .
git commit -m "Deploy update"
git push origin main
```

Cloud Build will automatically:

1. Detect the push
2. Build Docker images
3. Push to Container Registry
4. Deploy to VM

### Option B: Manual Trigger

In Cloud Build Console:

1. Go to **Triggers**
2. Click **Run** on target pipeline

## Step 6: Monitor Deployment

### View Build Logs

```bash
gcloud builds log --stream
```

### Check VM Deployment

```bash
gcloud compute ssh demo-vm --zone=us-central1-a --command="docker compose ps"
```

### View Application Logs

```bash
gcloud compute ssh demo-vm --zone=us-central1-a --command="docker compose logs -f"
```

## Step 7: Access Application

Get VM external IP:

```bash
gcloud compute instances describe demo-vm --zone=us-central1-a --format='get(networkInterfaces[0].accessConfigs[0].natIP)'
```

Access application:

- **Frontend**: `http://<VM_EXTERNAL_IP>`
- **Backend API**: `http://<VM_EXTERNAL_IP>/api/`
- **Database**: `<VM_EXTERNAL_IP>:27017` (internal only)

## Environment Variables

The deployment uses the following environment variables (set in `deploy.sh`):

| Variable | Default | Description |
|----------|---------|-------------|
| `MDB_USERNAME` | admin | MongoDB root username |
| `MDB_PASSWORD` | S3curePass123 | MongoDB root password |
| `MDB_NAME` | moviedb | MongoDB database name |
| `BACKEND_URI` | http://backend:5000/api/ | Backend API URI |

To change these, edit the `.env` section in `deploy.sh`.

## Troubleshooting

### Build Fails with "Permission Denied"
- Ensure Cloud Build service account has `roles/compute.instanceAdmin.v1`
- Verify VM has SSH access enabled

### Images Not Found in Container Registry
- Check that Cloud Build has `roles/storage.admin` permission
- Verify images were pushed: `gcloud container images list`

### Containers Not Starting on VM
- SSH into VM and check logs: `docker compose logs`
- Verify Docker is running: `docker ps`
- Check disk space: `df -h`

### SSH Connection Fails
- Verify VM zone matches `_VM_ZONE` in `cloudbuild.yaml`
- Check VM is running: `gcloud compute instances list`
- Verify SSH keys are configured

## Security Best Practices

1. **Use Secret Manager** for sensitive data:
   ```bash
   echo -n "your-password" | gcloud secrets create db-password --data-file=-
   ```

2. **Restrict Service Account Permissions** to minimum required

3. **Use VPC** to isolate VM network

4. **Enable Cloud Audit Logs** to track deployments

5. **Rotate Credentials** regularly

## Advanced Configuration

### Custom Build Machine Type
Edit `cloudbuild.yaml`:
```yaml
options:
  machineType: 'N1_HIGHCPU_8'  # Larger machine for faster builds
```

### Conditional Deployment
Add branch conditions in Cloud Build trigger settings

### Rollback Strategy
Keep previous image tags and update `docker-compose.yml` to use specific versions

## Cost Optimization

- Use `e2-medium` or smaller VM for development
- Set up automatic shutdown for non-production VMs
- Use Cloud Build's free tier (120 build-minutes/day)

## Next Steps

1. Set up monitoring with Cloud Monitoring
2. Configure Cloud Logging for centralized logs
3. Implement health checks
4. Set up automated backups for MongoDB volumes
5. Configure SSL/TLS with Cloud Load Balancer

## References

- [Cloud Build Documentation](https://cloud.google.com/build/docs)
- [Compute Engine Documentation](https://cloud.google.com/compute/docs)
- [Container Registry Documentation](https://cloud.google.com/container-registry/docs)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
