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
CLUSTER_NAME="memory-game-cluster"
ZONE="us-central1-a"
REGION="us-central1"
NAMESPACE="memory-game"

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
    gcloud services enable containerregistry.googleapis.com
    gcloud services enable compute.googleapis.com
    gcloud auth configure-docker
    print_info "Project setup complete!"
}

build_images() {
    print_info "Building Docker images..."
    
    print_info "Building backend image..."
    cd backend
    docker build -t memory-game-backend:latest .
    docker tag memory-game-backend:latest gcr.io/$PROJECT_ID/memory-game-backend:latest
    cd ..
    
    print_info "Building frontend image..."
    cd frontend
    docker build -t memory-game-frontend:latest .
    docker tag memory-game-frontend:latest gcr.io/$PROJECT_ID/memory-game-frontend:latest
    cd ..
    
    print_info "Docker images built successfully!"
}

push_images() {
    print_info "Pushing images to Google Container Registry..."
    
    docker push gcr.io/$PROJECT_ID/memory-game-backend:latest
    docker push gcr.io/$PROJECT_ID/memory-game-frontend:latest
    
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
    
    # Update image references
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/YOUR_PROJECT_ID/$PROJECT_ID/g" k8s/*-deployment.yaml
    else
        # Linux
        sed -i "s/YOUR_PROJECT_ID/$PROJECT_ID/g" k8s/*-deployment.yaml
    fi
    
    print_info "Manifests updated!"
}

deploy_application() {
    print_info "Deploying application..."
    
    # Create namespace
    kubectl apply -f k8s/namespace.yaml
    
    # Deploy backend
    print_info "Deploying backend..."
    kubectl apply -f k8s/backend-deployment.yaml
    kubectl apply -f k8s/backend-service.yaml
    kubectl rollout status deployment/memory-game-backend -n $NAMESPACE --timeout=300s
    
    # Deploy frontend
    print_info "Deploying frontend..."
    kubectl apply -f k8s/frontend-deployment.yaml
    kubectl apply -f k8s/frontend-service.yaml
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
            --build-only)
                check_prerequisites
                prompt_project_id
                setup_project
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

