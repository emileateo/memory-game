# GKE Deployment Guide for Pokemon Memory Game

This guide provides detailed steps to deploy the Pokemon Memory Game application to Google Kubernetes Engine (GKE).

## Prerequisites

Before you begin, ensure you have:

1. **Google Cloud Platform (GCP) Account**: Active GCP account with billing enabled
2. **gcloud CLI**: Google Cloud SDK installed and configured
3. **kubectl**: Kubernetes command-line tool
4. **Docker**: Installed and configured
5. **Domain Name** (Optional): For HTTPS/custom domain setup

## Table of Contents

1. [Initial Setup](#1-initial-setup)
2. [Build Docker Images](#2-build-docker-images)
3. [Push Images to Container Registry](#3-push-images-to-container-registry)
4. [Create GKE Cluster](#4-create-gke-cluster)
5. [Configure kubectl](#5-configure-kubectl)
6. [Deploy Application](#6-deploy-application)
7. [Configure Ingress and SSL](#7-configure-ingress-and-ssl)
8. [Access Your Application](#8-access-your-application)
9. [Monitoring and Logging](#9-monitoring-and-logging)
10. [Troubleshooting](#10-troubleshooting)
11. [Scaling and Updates](#11-scaling-and-updates)
12. [Cleanup](#12-cleanup)

---

## 1. Initial Setup

### 1.1 Set up your GCP project

```bash
# Set your project ID
export PROJECT_ID="your-gcp-project-id"

# Set the project
gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable container.googleapis.com
gcloud services enable containerregistry.googleapis.com
gcloud services enable compute.googleapis.com

# Configure Docker to use gcloud credentials
gcloud auth configure-docker
```

### 1.2 Configure environment variables

```bash
# Set deployment variables
export CLUSTER_NAME="memory-game-cluster"
export ZONE="us-central1-a"  # Choose your preferred zone
export NAMESPACE="memory-game"
export REGION="us-central1"  # For regional clusters
```

---

## 2. Build Docker Images

### 2.1 Build Backend Image

```bash
cd backend

# Build the Docker image
docker build -t memory-game-backend:latest .

# Test the image locally (optional)
docker run -p 5000:5000 memory-game-backend:latest

cd ..
```

### 2.2 Build Frontend Image

```bash
cd frontend

# Build the Docker image
docker build -t memory-game-frontend:latest .

# Test the image locally (optional)
docker run -p 8080:80 memory-game-frontend:latest

cd ..
```

---

## 3. Push Images to Container Registry

### 3.1 Tag Images for GCR

```bash
# Tag backend image
docker tag memory-game-backend:latest gcr.io/$PROJECT_ID/memory-game-backend:latest

# Tag frontend image
docker tag memory-game-frontend:latest gcr.io/$PROJECT_ID/memory-game-frontend:latest
```

### 3.2 Push to Google Container Registry

```bash
# Push backend image
docker push gcr.io/$PROJECT_ID/memory-game-backend:latest

# Push frontend image
docker push gcr.io/$PROJECT_ID/memory-game-frontend:latest

# Verify images are uploaded
gcloud container images list
```

---

## 4. Create GKE Cluster

### 4.1 Create a Standard Cluster (Recommended)

```bash
gcloud container clusters create $CLUSTER_NAME \
  --zone=$ZONE \
  --machine-type=e2-medium \
  --num-nodes=2 \
  --enable-autorepair \
  --enable-autoupgrade \
  --enable-ip-alias \
  --network="default" \
  --create-subnetwork="" \
  --enable-network-policy \
  --addons=HorizontalPodAutoscaling,HttpLoadBalancing \
  --enable-autoscaling \
  --min-nodes=2 \
  --max-nodes=4
```

**Note**: This creates a cluster with:
- 2 nodes (minimum)
- Auto-scaling up to 4 nodes
- Network policy enabled
- HTTP load balancing
- Auto-repair and auto-upgrade

### 4.2 Alternative: Regional Cluster (For Production)

For higher availability in production:

```bash
gcloud container clusters create $CLUSTER_NAME \
  --region=$REGION \
  --machine-type=e2-medium \
  --num-nodes=2 \
  --enable-autorepair \
  --enable-autoupgrade \
  --enable-ip-alias \
  --network="default" \
  --create-subnetwork="" \
  --enable-network-policy \
  --addons=HorizontalPodAutoscaling,HttpLoadBalancing \
  --enable-autoscaling \
  --min-nodes=2 \
  --max-nodes=6
```

### 4.3 Create Cluster with Custom Configuration

For fine-tuned control:

```bash
gcloud container clusters create $CLUSTER_NAME \
  --zone=$ZONE \
  --machine-type=n1-standard-2 \
  --disk-size=50 \
  --disk-type=pd-standard \
  --num-nodes=3 \
  --enable-autorepair \
  --enable-autoupgrade \
  --enable-ip-alias \
  --cluster-version=latest \
  --enable-network-policy \
  --addons=HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver \
  --scopes=https://www.googleapis.com/auth/cloud-platform
```

---

## 5. Configure kubectl

```bash
# Get cluster credentials
gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE

# Verify connection
kubectl cluster-info

# Check nodes
kubectl get nodes
```

---

## 6. Deploy Application

### 6.1 Update Kubernetes Manifests

Before deploying, update the image references in the Kubernetes manifests:

```bash
# Update backend deployment
sed -i '' "s/YOUR_PROJECT_ID/$PROJECT_ID/g" k8s/backend-deployment.yaml

# Update frontend deployment
sed -i '' "s/YOUR_PROJECT_ID/$PROJECT_ID/g" k8s/frontend-deployment.yaml

# For Linux, use:
# sed -i "s/YOUR_PROJECT_ID/$PROJECT_ID/g" k8s/*-deployment.yaml
```

### 6.2 Create Namespace

```bash
kubectl apply -f k8s/namespace.yaml
```

### 6.3 Deploy Backend

```bash
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/backend-service.yaml

# Wait for deployment to be ready
kubectl rollout status deployment/memory-game-backend -n $NAMESPACE

# Check backend pods
kubectl get pods -n $NAMESPACE -l app=memory-game-backend
```

### 6.4 Deploy Frontend

```bash
kubectl apply -f k8s/frontend-deployment.yaml
kubectl apply -f k8s/frontend-service.yaml

# Wait for deployment to be ready
kubectl rollout status deployment/memory-game-frontend -n $NAMESPACE

# Check frontend pods
kubectl get pods -n $NAMESPACE -l app=memory-game-frontend
```

### 6.5 Verify Deployments

```bash
# Get all resources in namespace
kubectl get all -n $NAMESPACE

# Check service endpoints
kubectl get endpoints -n $NAMESPACE

# View backend logs
kubectl logs -n $NAMESPACE -l app=memory-game-backend --tail=50

# View frontend logs
kubectl logs -n $NAMESPACE -l app=memory-game-frontend --tail=50
```

---

## 7. Configure Ingress and SSL

### 7.1 Option A: Simple LoadBalancer (Quick Start)

For quick testing without a domain:

```bash
# The frontend service already uses LoadBalancer type
# Get the external IP
kubectl get service memory-game-frontend -n $NAMESPACE

# Access the application
# http://EXTERNAL-IP
```

### 7.2 Option B: Ingress with SSL (Production)

#### 7.2.1 Reserve Static IP

```bash
# Reserve static IP
gcloud compute addresses create memory-game-ip \
  --global \
  --ip-version=IPV4

# Get the IP address
gcloud compute addresses describe memory-game-ip --global
```

#### 7.2.2 Update DNS

Point your domain to the reserved IP:

```bash
# If using Google Cloud DNS
gcloud dns record-sets transaction start --zone=YOUR_ZONE
gcloud dns record-sets transaction add YOUR_IP \
  --name=your-domain.com. \
  --type=A \
  --ttl=300 \
  --zone=YOUR_ZONE
gcloud dns record-sets transaction execute --zone=YOUR_ZONE
```

#### 7.2.3 Update Ingress Configuration

```bash
# Update domain in ingress.yaml
sed -i '' "s/your-domain.com/YOUR_ACTUAL_DOMAIN/g" k8s/ingress.yaml

# Update domain in managed-certificate.yaml
sed -i '' "s/your-domain.com/YOUR_ACTUAL_DOMAIN/g" k8s/managed-certificate.yaml
```

#### 7.2.4 Deploy Managed Certificate and Ingress

```bash
# Deploy managed certificate
kubectl apply -f k8s/managed-certificate.yaml

# Wait for certificate to be provisioned (this takes 10-60 minutes)
kubectl get managedcertificate -n $NAMESPACE

# Deploy ingress
kubectl apply -f k8s/ingress.yaml

# Check ingress status
kubectl get ingress -n $NAMESPACE
```

#### 7.2.5 Alternative: Self-Signed Certificate for Testing

For development/testing without waiting for managed certificate:

```bash
# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=your-domain.com/O=your-domain.com"

# Create Kubernetes secret
kubectl create secret tls memory-game-tls \
  --cert=tls.crt --key=tls.key \
  -n $NAMESPACE

# Update ingress to use secret instead of managed cert
# (modify k8s/ingress.yaml to reference secret)
```

---

## 8. Access Your Application

### 8.1 Get Access Information

```bash
# Get LoadBalancer IP
LB_IP=$(kubectl get service memory-game-frontend -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Application available at: http://$LB_IP"

# Or get Ingress IP
INGRESS_IP=$(kubectl get ingress memory-game-ingress -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Application available at: http://$INGRESS_IP"
```

### 8.2 Test the Application

1. Open browser and navigate to the URL
2. Play a game to verify frontend-backend communication
3. Check leaderboard functionality
4. Verify scores are being saved

---

## 9. Monitoring and Logging

### 9.1 View Application Logs

```bash
# Backend logs
kubectl logs -n $NAMESPACE -l app=memory-game-backend --tail=100 -f

# Frontend logs
kubectl logs -n $NAMESPACE -l app=memory-game-frontend --tail=100 -f

# Logs for a specific pod
kubectl logs -n $NAMESPACE POD_NAME -f
```

### 9.2 Check Pod Status

```bash
# Get pod status
kubectl get pods -n $NAMESPACE

# Describe a pod for detailed information
kubectl describe pod POD_NAME -n $NAMESPACE

# Check events in namespace
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'
```

### 9.3 Enable Cloud Logging and Monitoring

```bash
# Enable Google Cloud Operations (formerly Stackdriver)
gcloud container clusters update $CLUSTER_NAME \
  --zone=$ZONE \
  --enable-cloud-logging \
  --enable-cloud-monitoring

# View logs in Cloud Console
# https://console.cloud.google.com/logs/query
```

---

## 10. Troubleshooting

### 10.1 Common Issues

#### Issue: Pods not starting

```bash
# Check pod status
kubectl get pods -n $NAMESPACE

# Describe pod for errors
kubectl describe pod POD_NAME -n $NAMESPACE

# Check logs
kubectl logs POD_NAME -n $NAMESPACE
```

#### Issue: Can't connect to backend

```bash
# Verify backend service exists
kubectl get svc memory-game-backend -n $NAMESPACE

# Check endpoints
kubectl get endpoints memory-game-backend -n $NAMESPACE

# Test connectivity from frontend pod
kubectl exec -n $NAMESPACE -it $(kubectl get pods -n $NAMESPACE -l app=memory-game-frontend -o name | head -1) -- wget -O- http://memory-game-backend/api/results
```

#### Issue: Frontend loads but API calls fail

```bash
# Check nginx configuration in frontend pod
kubectl exec -n $NAMESPACE -it $(kubectl get pods -n $NAMESPACE -l app=memory-game-frontend -o name | head -1) -- cat /etc/nginx/conf.d/default.conf

# Check nginx logs
kubectl logs -n $NAMESPACE -l app=memory-game-frontend --tail=100 | grep error
```

#### Issue: Image pull errors

```bash
# Verify images exist
gcloud container images list-tags gcr.io/$PROJECT_ID/memory-game-backend
gcloud container images list-tags gcr.io/$PROJECT_ID/memory-game-frontend

# Check image pull secrets
kubectl get secret -n $NAMESPACE

# Verify Docker authentication
gcloud auth configure-docker
```

#### Issue: Database data not persisting

**Note**: Current setup uses ephemeral storage. For production, you should use:

1. **Cloud SQL**: Managed PostgreSQL/MySQL
2. **Firestore**: Serverless NoSQL database
3. **Persistent Volumes**: Kubernetes persistent storage

See [11.5 Database Persistence](#115-database-persistence) section.

### 10.2 Debugging Commands

```bash
# Get cluster info
kubectl cluster-info

# Get node information
kubectl get nodes -o wide

# Check resource usage
kubectl top nodes
kubectl top pods -n $NAMESPACE

# Check configuration
kubectl get configmap -n $NAMESPACE
kubectl get secret -n $NAMESPACE

# Port-forward for local testing
kubectl port-forward -n $NAMESPACE svc/memory-game-frontend 8080:80
kubectl port-forward -n $NAMESPACE svc/memory-game-backend 5000:80
```

---

## 11. Scaling and Updates

### 11.1 Manual Scaling

```bash
# Scale backend replicas
kubectl scale deployment memory-game-backend --replicas=3 -n $NAMESPACE

# Scale frontend replicas
kubectl scale deployment memory-game-frontend --replicas=3 -n $NAMESPACE

# Verify scaling
kubectl get pods -n $NAMESPACE
```

### 11.2 Horizontal Pod Autoscaler

Create HPA for automatic scaling:

```yaml
# k8s/backend-hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: memory-game-backend-hpa
  namespace: memory-game
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: memory-game-backend
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

Apply HPA:

```bash
kubectl apply -f k8s/backend-hpa.yaml

# Check HPA status
kubectl get hpa -n $NAMESPACE
```

### 11.3 Rolling Updates

```bash
# Update backend image
kubectl set image deployment/memory-game-backend \
  backend=gcr.io/$PROJECT_ID/memory-game-backend:v2.0 \
  -n $NAMESPACE

# Monitor rollout
kubectl rollout status deployment/memory-game-backend -n $NAMESPACE

# Rollback if needed
kubectl rollout undo deployment/memory-game-backend -n $NAMESPACE
```

### 11.4 Build and Push New Version

```bash
# Build new version
cd backend && docker build -t memory-game-backend:v2.0 .
cd ../frontend && docker build -t memory-game-frontend:v2.0 .

# Tag for GCR
docker tag memory-game-backend:v2.0 gcr.io/$PROJECT_ID/memory-game-backend:v2.0
docker tag memory-game-frontend:v2.0 gcr.io/$PROJECT_ID/memory-game-frontend:v2.0

# Push
docker push gcr.io/$PROJECT_ID/memory-game-backend:v2.0
docker push gcr.io/$PROJECT_ID/memory-game-frontend:v2.0

# Update deployments
# (either use kubectl set image or update YAML files)
```

### 11.5 Database Persistence

**Current Setup**: SQLite with ephemeral storage (data lost on pod restart)

**Production Options**:

#### Option 1: Cloud SQL (Recommended)

1. Create Cloud SQL instance
2. Update backend to use Cloud SQL
3. Use Cloud SQL Proxy sidecar or Private IP

#### Option 2: Persistent Volumes

```bash
# Create PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: backend-pvc
  namespace: memory-game
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: standard-rwo
EOF

# Update backend deployment to use PVC
# (uncomment volumes section in backend-deployment.yaml)
```

---

## 12. Cleanup

### 12.1 Delete Kubernetes Resources

```bash
# Delete all resources in namespace
kubectl delete all --all -n $NAMESPACE

# Delete ingress and certificate
kubectl delete ingress memory-game-ingress -n $NAMESPACE
kubectl delete managedcertificate memory-game-certificate -n $NAMESPACE

# Delete namespace
kubectl delete namespace $NAMESPACE
```

### 12.2 Delete GKE Cluster

```bash
# Delete the cluster
gcloud container clusters delete $CLUSTER_NAME --zone=$ZONE

# Or for regional cluster
gcloud container clusters delete $CLUSTER_NAME --region=$REGION
```

### 12.3 Delete Container Images

```bash
# Delete images from GCR
gcloud container images delete gcr.io/$PROJECT_ID/memory-game-backend:latest
gcloud container images delete gcr.io/$PROJECT_ID/memory-game-frontend:latest

# Or delete entire repository
gcloud container images delete gcr.io/$PROJECT_ID/memory-game-backend
gcloud container images delete gcr.io/$PROJECT_ID/memory-game-frontend
```

### 12.4 Delete Static IP

```bash
# Release static IP
gcloud compute addresses delete memory-game-ip --global
```

### 12.5 Full Cleanup Script

```bash
#!/bin/bash

# Set variables
export PROJECT_ID="your-gcp-project-id"
export CLUSTER_NAME="memory-game-cluster"
export ZONE="us-central1-a"
export NAMESPACE="memory-game"

# Delete Kubernetes resources
kubectl delete namespace $NAMESPACE --wait=true

# Delete cluster
gcloud container clusters delete $CLUSTER_NAME --zone=$ZONE --quiet

# Delete images
gcloud container images delete gcr.io/$PROJECT_ID/memory-game-backend:latest --quiet
gcloud container images delete gcr.io/$PROJECT_ID/memory-game-frontend:latest --quiet

# Release static IP
gcloud compute addresses delete memory-game-ip --global --quiet

echo "Cleanup complete!"
```

---

## Additional Resources

- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Google Cloud Container Registry](https://cloud.google.com/container-registry/docs)
- [GKE Ingress](https://cloud.google.com/kubernetes-engine/docs/concepts/ingress)
- [Cloud SQL for PostgreSQL](https://cloud.google.com/sql/docs/postgres)

---

## Cost Estimation

Approximate monthly costs for a small deployment:

- **GKE Cluster** (2 nodes, e2-medium): ~$70/month
- **Container Registry**: ~$5/month
- **Load Balancer**: ~$20/month
- **Network Egress**: ~$10-50/month (depends on traffic)
- **Managed Certificate**: Free

**Total**: ~$105-145/month for basic setup

For production, consider:
- Reserved instances for nodes (30% discount)
- Regional persistent disks
- Cloud NAT to reduce egress costs
- Cloud SQL for database

---

## Security Considerations

1. **Enable Pod Security Policies** or **Pod Security Standards**
2. **Use Network Policies** for micro-segmentation
3. **Rotate certificates** regularly
4. **Enable GKE Workload Identity** for better security
5. **Use Secret Manager** for sensitive data
6. **Enable Binary Authorization** for production
7. **Regularly update images** with security patches
8. **Implement resource quotas** and limits

---

## Support

For issues or questions:
1. Check [Troubleshooting](#10-troubleshooting) section
2. Review Kubernetes and GKE logs
3. Consult official documentation
4. Contact Google Cloud Support

---

**Happy Deploying! 🚀**

