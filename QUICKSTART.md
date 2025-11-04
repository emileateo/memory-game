# Quick Start: Deploy to GKE

This guide gets you up and running quickly with the Pokemon Memory Game on Google Kubernetes Engine.

## Prerequisites Checklist

- [ ] Google Cloud Platform account with billing enabled
- [ ] `gcloud` CLI installed and logged in (`gcloud auth login`)
- [ ] `kubectl` installed
- [ ] `docker` installed and running
- [ ] Your GCP Project ID

## 🚀 Automated Deployment (5 minutes)

### 1. Set Your Project ID

```bash
export PROJECT_ID="your-gcp-project-id"
```

### 2. Run Deployment Script

```bash
./deploy.sh --project $PROJECT_ID
```

The script will:
- Enable required GCP APIs
- Build Docker images
- Push to Google Container Registry
- Create GKE cluster (if needed)
- Deploy the application
- Display the access URL

### 3. Access Your Game

The script will output the LoadBalancer IP. Open it in your browser!

```
Application is now accessible at:
http://YOUR_EXTERNAL_IP
```

### 4. Clean Up (When Done)

```bash
./cleanup.sh --project $PROJECT_ID --force
```

---

## 📋 Manual Deployment Steps

If you prefer to do it manually or understand each step:

### Step 1: Enable APIs

```bash
gcloud services enable container.googleapis.com
gcloud services enable containerregistry.googleapis.com
gcloud services enable compute.googleapis.com
```

### Step 2: Build and Push Images

```bash
# Build backend
cd backend
docker build -t gcr.io/$PROJECT_ID/memory-game-backend:latest .
docker push gcr.io/$PROJECT_ID/memory-game-backend:latest
cd ..

# Build frontend
cd frontend
docker build -t gcr.io/$PROJECT_ID/memory-game-frontend:latest .
docker push gcr.io/$PROJECT_ID/memory-game-frontend:latest
cd ..
```

### Step 3: Create GKE Cluster

```bash
gcloud container clusters create memory-game-cluster \
  --zone=us-central1-a \
  --machine-type=e2-medium \
  --num-nodes=2 \
  --enable-autorepair \
  --enable-autoupgrade
```

### Step 4: Get Credentials

```bash
gcloud container clusters get-credentials memory-game-cluster --zone=us-central1-a
```

### Step 5: Update Manifests

```bash
# Replace YOUR_PROJECT_ID with your actual project ID
sed -i '' "s/YOUR_PROJECT_ID/$PROJECT_ID/g" k8s/*-deployment.yaml
```

### Step 6: Deploy

```bash
kubectl apply -f k8s/
```

### Step 7: Get Access URL

```bash
kubectl get svc memory-game-frontend -n memory-game
```

Wait for the LoadBalancer to provision, then access the EXTERNAL-IP.

---

## 🐛 Troubleshooting

### Images won't push

```bash
gcloud auth configure-docker
```

### Cluster creation fails

Check your quotas:
```bash
gcloud compute project-info describe --project=$PROJECT_ID
```

### Can't access the app

Check pod status:
```bash
kubectl get pods -n memory-game
kubectl logs -n memory-game -l app=memory-game-frontend
kubectl logs -n memory-game -l app=memory-game-backend
```

### Clean slate

Remove everything and start over:
```bash
./cleanup.sh --project $PROJECT_ID --force
```

---

## 📚 Next Steps

- [Full Deployment Guide](GKE_DEPLOYMENT.md) - Comprehensive guide with all options
- [Production Checklist](GKE_DEPLOYMENT.md#security-considerations) - Security and best practices
- [Scaling Guide](GKE_DEPLOYMENT.md#11-scaling-and-updates) - Scale your application
- [Cost Optimization](GKE_DEPLOYMENT.md#cost-estimation) - Reduce costs

---

## 💡 Tips

1. **First deployment takes longer**: Creating cluster and provisioning LoadBalancer ~5-10 minutes
2. **Subsequent deployments are faster**: Just update images, cluster already exists
3. **Check costs**: Monitor in GCP Console > Billing
4. **Use `.dockerignore`**: Already configured for faster builds
5. **Multiple environments**: Use different namespaces/clusters

---

## 📞 Need Help?

1. Check the [Troubleshooting](GKE_DEPLOYMENT.md#10-troubleshooting) section
2. View logs: `kubectl logs -n memory-game -f -l app=memory-game-frontend`
3. See full guide: [GKE_DEPLOYMENT.md](GKE_DEPLOYMENT.md)

