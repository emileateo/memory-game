#!/bin/bash

# Pokemon Memory Game - GKE Deployment Script
# This script automates the deployment to GKE

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID=""
CLUSTER_NAME="emilea-202511"
ZONE="us-central1"
REGION="us-central1"   # Artifact Registry region (e.g., us-central1)
REPO="memory-game"      # Artifact Registry repository name
NAMESPACE="memory-game"
TAG="v$(date +%Y%m%d%H%M%S)"  # default unique tag per run

# Functions
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    print_info "Checking prerequisites..."
    
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI is not installed"
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi
    
    print_info "All prerequisites met!"
}

prompt_project_id() {
    if [ -z "$PROJECT_ID" ]; then
        read -p "Enter your GCP Project ID: " PROJECT_ID
    fi
    
    if [ -z "$PROJECT_ID" ]; then
        print_error "Project ID is required"
        exit 1
    fi
}

setup_project() {
    print_info "Setting up GCP project..."
    gcloud config set project $PROJECT_ID
    gcloud services enable container.googleapis.com
    gcloud services enable artifactregistry.googleapis.com
    gcloud services enable compute.googleapis.com
    # Configure Docker to auth to Artifact Registry for this region
    gcloud auth configure-docker $REGION-docker.pkg.dev
    print_info "Project setup complete!"
}

ensure_artifact_registry_repo() {
    print_info "Ensuring Artifact Registry repo exists: $REPO in $REGION"
    if ! gcloud artifacts repositories describe $REPO --location=$REGION >/dev/null 2>&1; then
        gcloud artifacts repositories create $REPO \
          --repository-format=docker \
          --location=$REGION \
          --description="Memory Game images"
        print_info "Created Artifact Registry repo: $REPO"
    else
        print_info "Artifact Registry repo already exists"
    fi
}

build_images() {
    print_info "Building Docker images..."
    
    print_info "Building backend image..."
    cd backend
    docker build --platform=linux/amd64 -t $REGION-docker.pkg.dev/$PROJECT_ID/$REPO/backend:$TAG .
    cd ..
    
    print_info "Building frontend image..."
    cd frontend
    docker build --platform=linux/amd64 -t $REGION-docker.pkg.dev/$PROJECT_ID/$REPO/frontend:$TAG .
    cd ..
    
    print_info "Docker images built successfully!"
}

push_images() {
    print_info "Pushing images to Artifact Registry..."
    
    docker push $REGION-docker.pkg.dev/$PROJECT_ID/$REPO/backend:$TAG
    docker push $REGION-docker.pkg.dev/$PROJECT_ID/$REPO/frontend:$TAG
    
    print_info "Images pushed successfully!"
}

create_cluster() {
    print_info "Creating GKE cluster..."
    
    # Check if cluster already exists
    if gcloud container clusters describe $CLUSTER_NAME --zone=$ZONE &> /dev/null; then
        print_warn "Cluster already exists, skipping creation"
    else
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
        
        print_info "Cluster created successfully!"
    fi
}

configure_kubectl() {
    print_info "Configuring kubectl..."
    gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE
    print_info "kubectl configured!"
}

update_manifests() {
    print_info "Updating Kubernetes manifests..."
    
    # No-op for templated manifests. We'll set images via kubectl set image.
    
    print_info "Manifests updated!"
}

deploy_application() {
    print_info "Deploying application..."
    
    # Create namespace (if you maintain a separate namespace file, apply it here)
    kubectl get ns $NAMESPACE >/dev/null 2>&1 || kubectl create ns $NAMESPACE
    
    # Apply manifests (adjust to your consolidated files if needed)
    print_info "Applying K8s manifests..."
    if [ -d k8s ]; then
      # Apply in order if split files exist
      if [ -f k8s/01-config.yaml ]; then kubectl apply -f k8s/01-config.yaml; fi
      if [ -f k8s/10-backend.yaml ]; then kubectl apply -f k8s/10-backend.yaml; fi
      if [ -f k8s/20-frontend.yaml ]; then kubectl apply -f k8s/20-frontend.yaml; fi
      if [ -f k8s/30-ingress.yaml ]; then kubectl apply -f k8s/30-ingress.yaml; fi
      # Legacy split layout support
      if [ -f k8s/backend-deployment.yaml ]; then kubectl apply -f k8s/backend-deployment.yaml; fi
      if [ -f k8s/backend-service.yaml ]; then kubectl apply -f k8s/backend-service.yaml; fi
      if [ -f k8s/frontend-deployment.yaml ]; then kubectl apply -f k8s/frontend-deployment.yaml; fi
      if [ -f k8s/frontend-service.yaml ]; then kubectl apply -f k8s/frontend-service.yaml; fi
      if [ -f k8s/ingress.yaml ]; then kubectl apply -f k8s/ingress.yaml; fi
    fi

    # Point deployments to the freshly built images
    print_info "Updating Deployments to new images..."
    kubectl set image deployment/memory-game-backend \
      backend=$REGION-docker.pkg.dev/$PROJECT_ID/$REPO/backend:$TAG \
      -n $NAMESPACE
    kubectl set image deployment/memory-game-frontend \
      frontend=$REGION-docker.pkg.dev/$PROJECT_ID/$REPO/frontend:$TAG \
      -n $NAMESPACE

    # Wait for rollouts
    kubectl rollout status deployment/memory-game-backend -n $NAMESPACE --timeout=300s
    kubectl rollout status deployment/memory-game-frontend -n $NAMESPACE --timeout=300s
    
    print_info "Application deployed successfully!"
}

get_access_info() {
    print_info "Getting access information..."
    
    # Get LoadBalancer IP
    echo ""
    print_info "Waiting for LoadBalancer to be provisioned..."
    sleep 10
    
    LB_IP=$(kubectl get service memory-game-frontend -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    if [ -z "$LB_IP" ]; then
        print_warn "LoadBalancer IP not ready yet. Run 'kubectl get svc -n $NAMESPACE' to check status"
    else
        echo ""
        print_info "=========================================="
        print_info "Application is now accessible at:"
        print_info "http://$LB_IP"
        print_info "=========================================="
        echo ""
    fi
    
    # Show all resources
    print_info "Current deployment status:"
    kubectl get all -n $NAMESPACE
}

main() {
    echo ""
    print_info "=========================================="
    print_info "Pokemon Memory Game - GKE Deployment"
    print_info "=========================================="
    echo ""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --project)
                PROJECT_ID="$2"
                shift 2
                ;;
            --cluster)
                CLUSTER_NAME="$2"
                shift 2
                ;;
            --zone)
                ZONE="$2"
                shift 2
                ;;
            --region)
                REGION="$2"
                shift 2
                ;;
            --repo)
                REPO="$2"
                shift 2
                ;;
            --tag)
                TAG="$2"
                shift 2
                ;;
            --build-only)
                check_prerequisites
                prompt_project_id
                setup_project
                ensure_artifact_registry_repo
                build_images
                push_images
                exit 0
                ;;
            --deploy-only)
                check_prerequisites
                prompt_project_id
                configure_kubectl
                update_manifests
                deploy_application
                get_access_info
                exit 0
                ;;
            --help)
                echo "Usage: $0 [options]"
                echo ""
                echo "Options:"
                echo "  --project ID         GCP Project ID"
                echo "  --cluster NAME       Cluster name (default: memory-game-cluster)"
                echo "  --zone ZONE          GCP Zone (default: us-central1-a)"
                echo "  --region REGION      Artifact Registry region (default: us-central1)"
                echo "  --repo NAME          Artifact Registry repo name (default: memory-game)"
                echo "  --tag TAG            Image tag (default: timestamp)"
                echo "  --build-only         Only build and push images"
                echo "  --deploy-only        Only deploy to existing cluster"
                echo "  --help               Show this help message"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Full deployment
    check_prerequisites
    prompt_project_id
    setup_project
    ensure_artifact_registry_repo
    build_images
    push_images
    create_cluster
    configure_kubectl
    update_manifests
    deploy_application
    get_access_info
    
    print_info "Deployment complete!"
    echo ""
}

main "$@"

