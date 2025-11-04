#!/bin/bash

# Pokemon Memory Game - GKE Cleanup Script
# This script removes all resources created during deployment

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
NAMESPACE="memory-game"

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

confirm() {
    read -p "$(print_warn "$1 (y/N)") " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

main() {
    echo ""
    print_info "=========================================="
    print_info "Pokemon Memory Game - GKE Cleanup"
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
            --force)
                FORCE=true
                shift
                ;;
            --help)
                echo "Usage: $0 [options]"
                echo ""
                echo "Options:"
                echo "  --project ID         GCP Project ID"
                echo "  --cluster NAME       Cluster name (default: memory-game-cluster)"
                echo "  --zone ZONE          GCP Zone (default: us-central1-a)"
                echo "  --force              Skip confirmation prompts"
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
    
    if [ -z "$PROJECT_ID" ]; then
        read -p "Enter your GCP Project ID: " PROJECT_ID
    fi
    
    if [ -z "$PROJECT_ID" ]; then
        print_error "Project ID is required"
        exit 1
    fi
    
    print_warn "This will delete:"
    echo "  - GKE Cluster: $CLUSTER_NAME"
    echo "  - Kubernetes namespace: $NAMESPACE"
    echo "  - Container images from GCR"
    echo "  - Static IP (if created)"
    echo ""
    
    if [ -z "$FORCE" ]; then
        if ! confirm "Are you sure you want to continue?"; then
            print_info "Cleanup cancelled"
            exit 0
        fi
    fi
    
    # Set project
    gcloud config set project $PROJECT_ID
    
    # Delete namespace and all resources
    print_info "Deleting Kubernetes resources..."
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        kubectl delete namespace $NAMESPACE --wait=true
        print_info "Namespace deleted"
    else
        print_warn "Namespace not found, skipping"
    fi
    
    # Delete ingress and certificate
    print_info "Deleting ingress resources..."
    kubectl delete ingress memory-game-ingress -n default 2>/dev/null || true
    kubectl delete managedcertificate memory-game-certificate -n default 2>/dev/null || true
    
    # Delete cluster
    print_info "Deleting GKE cluster..."
    if gcloud container clusters describe $CLUSTER_NAME --zone=$ZONE &> /dev/null; then
        gcloud container clusters delete $CLUSTER_NAME --zone=$ZONE --quiet
        print_info "Cluster deleted"
    else
        print_warn "Cluster not found, skipping"
    fi
    
    # Delete images
    print_info "Deleting container images..."
    gcloud container images delete gcr.io/$PROJECT_ID/memory-game-backend:latest --quiet 2>/dev/null || true
    gcloud container images delete gcr.io/$PROJECT_ID/memory-game-frontend:latest --quiet 2>/dev/null || true
    
    # Delete static IP
    print_info "Checking for static IP..."
    if gcloud compute addresses describe memory-game-ip --global &> /dev/null; then
        if [ -z "$FORCE" ]; then
            if confirm "Delete static IP: memory-game-ip"; then
                gcloud compute addresses delete memory-game-ip --global --quiet
                print_info "Static IP deleted"
            fi
        else
            gcloud compute addresses delete memory-game-ip --global --quiet
            print_info "Static IP deleted"
        fi
    else
        print_warn "Static IP not found, skipping"
    fi
    
    print_info "Cleanup complete!"
    echo ""
}

main "$@"

