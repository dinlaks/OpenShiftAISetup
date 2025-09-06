#!/bin/bash

# OpenShift AI Operators Uninstall Script
# This script removes operators in the reverse order of installation

set -e

echo "=== Uninstalling OpenShift AI Operators ==="

# Function to wait for resource to be deleted
wait_for_deletion() {
    local resource_type=$1
    local resource_name=$2
    local namespace=$3
    local timeout=${4:-300}
    
    echo "   Waiting for $resource_type/$resource_name to be deleted..."
    local count=0
    while [ $count -lt $timeout ]; do
        if ! oc get $resource_type $resource_name -n $namespace >/dev/null 2>&1; then
            echo "   ✓ $resource_type/$resource_name deleted"
            return 0
        fi
        sleep 5
        count=$((count + 5))
    done
    echo "   ⚠ Timeout waiting for $resource_type/$resource_name to be deleted (may still exist)"
    return 1
}

# Phase 3: Remove AI Platform Operator first
echo "--- Phase 3: Removing AI Platform Operator ---"

echo "6. Removing RHOAI Operator..."
echo "   Removing DataScienceCluster..."
oc delete datasciencecluster default-dsc --ignore-not-found=true
wait_for_deletion "datasciencecluster" "default-dsc" "" 300

echo "   Removing RHOAI Operator CRDs..."
oc delete -k rhoai-operator/overlays/crds/ --ignore-not-found=true

echo "   Removing RHOAI Operator..."
oc delete -k rhoai-operator/base/ --ignore-not-found=true
wait_for_deletion "csv" "rhods-operator" "redhat-ods-operator" 300

# Phase 2: Remove Platform Operators
echo "--- Phase 2: Removing Platform Operators ---"

echo "5. Removing Authorino Operator..."
oc delete -k authorino-operator/base/ --ignore-not-found=true
# Wait for any CSV with authorino in the name
echo "   Waiting for Authorino CSV to be deleted..."
oc get csv -n openshift-operators | grep authorino | awk '{print $1}' | xargs -r oc delete csv -n openshift-operators --ignore-not-found=true
wait_for_deletion "csv" "authorino-operator" "openshift-operators" 300

echo "4. Removing OpenShift ServiceMesh Operator..."
oc delete -k servicemesh-operator/base/ --ignore-not-found=true
# Wait for any CSV with servicemesh in the name
echo "   Waiting for ServiceMesh CSV to be deleted..."
oc get csv -n openshift-operators | grep servicemesh | awk '{print $1}' | xargs -r oc delete csv -n openshift-operators --ignore-not-found=true
wait_for_deletion "csv" "servicemeshoperator" "openshift-operators" 300

echo "3. Removing OpenShift Serverless Operator..."
oc delete -k serverless-operator/base/ --ignore-not-found=true
wait_for_deletion "csv" "serverless-operator" "openshift-serverless" 300

# Phase 1: Remove Infrastructure Operators last
echo "--- Phase 1: Removing Infrastructure Operators ---"

echo "2. Removing NVIDIA GPU Operator..."
echo "   Removing GPU ClusterPolicy..."
oc delete clusterpolicy gpu-cluster-policy --ignore-not-found=true
wait_for_deletion "clusterpolicy" "gpu-cluster-policy" "" 300

echo "   Removing NVIDIA GPU Operator CRDs..."
oc delete -k nvidia-operator/overlays/crds/ --ignore-not-found=true

echo "   Removing NVIDIA GPU Operator..."
oc delete -k nvidia-operator/base/ --ignore-not-found=true
wait_for_deletion "csv" "gpu-operator-certified" "nvidia-gpu-operator" 300

echo "1. Removing NFD Operator..."
echo "   Removing NFD instance..."
oc delete nodefeaturediscovery nfd-instance -n openshift-nfd --ignore-not-found=true
wait_for_deletion "nodefeaturediscovery" "nfd-instance" "openshift-nfd" 300

echo "   Removing NFD Operator CRDs..."
oc delete -k nfd-operator/overlays/crds/ --ignore-not-found=true

echo "   Removing NFD Operator..."
oc delete -k nfd-operator/base/ --ignore-not-found=true
wait_for_deletion "csv" "nfd-operator" "openshift-nfd" 300

# Clean up any remaining resources
echo "--- Cleaning up remaining resources ---"

echo "Removing any remaining subscriptions..."
oc delete subscription --all -n openshift-nfd --ignore-not-found=true
oc delete subscription --all -n nvidia-gpu-operator --ignore-not-found=true
oc delete subscription --all -n openshift-serverless --ignore-not-found=true
oc delete subscription --all -n redhat-ods-operator --ignore-not-found=true

echo "Removing any remaining operator groups..."
oc delete operatorgroup --all -n openshift-nfd --ignore-not-found=true
oc delete operatorgroup --all -n nvidia-gpu-operator --ignore-not-found=true
oc delete operatorgroup --all -n openshift-serverless --ignore-not-found=true
oc delete operatorgroup --all -n redhat-ods-operator --ignore-not-found=true

echo "Removing any remaining install plans..."
oc delete installplan --all -n openshift-nfd --ignore-not-found=true
oc delete installplan --all -n nvidia-gpu-operator --ignore-not-found=true
oc delete installplan --all -n openshift-serverless --ignore-not-found=true
oc delete installplan --all -n redhat-ods-operator --ignore-not-found=true

echo "Removing any remaining CSVs..."
oc delete csv --all -n openshift-nfd --ignore-not-found=true
oc delete csv --all -n nvidia-gpu-operator --ignore-not-found=true
oc delete csv --all -n openshift-serverless --ignore-not-found=true
oc delete csv --all -n redhat-ods-operator --ignore-not-found=true

echo "=== All operators uninstalled successfully! ==="
echo ""
echo "Uninstall Summary:"
echo "✓ RHOAI Operator and DataScienceCluster removed"
echo "✓ Authorino Operator removed"
echo "✓ OpenShift ServiceMesh Operator removed"
echo "✓ OpenShift Serverless Operator removed"
echo "✓ NVIDIA GPU Operator and ClusterPolicy removed"
echo "✓ NFD Operator and NFD instance removed"
echo "✓ All remaining resources cleaned up"
echo ""