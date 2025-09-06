#!/bin/bash

# OpenShift AI Operators Deployment Script
# This script deploys operators in the correct dependency order

set -e

echo "=== Deploying OpenShift AI Operators in Dependency Order ==="

# Phase 1: Infrastructure Operators (must be first)
echo "--- Phase 1: Deploying Infrastructure Operators ---"

echo "1. Deploying NFD Operator..."
oc apply -k nfd-operator/base/
echo "   Waiting for NFD Operator to be ready..."
oc wait --for=condition=Ready pod -l app.kubernetes.io/name=nfd -n openshift-nfd --timeout=300s

echo "   Applying NFD Overlay (CRDs)..."
oc apply -k nfd-operator/overlays/crds/
echo "   Waiting for NFD instance to be Available..."
oc wait --for=jsonpath='{.status.conditions[?(@.type=="Available")].status}'=True nfd-instance -n openshift-nfd --timeout=300s

echo "2. Deploying NVIDIA GPU Operator..."
oc apply -k nvidia-operator/base/
echo "   Waiting for NVIDIA GPU Operator to be ready..."
oc wait --for=condition=Ready pod -l app.kubernetes.io/name=gpu-operator -n nvidia-gpu-operator --timeout=300s

echo "   Applying NVIDIA GPU Operator Overlay (CRDs)..."
oc apply -k nvidia-operator/overlays/crds/
echo "   Waiting for GPU ClusterPolicy to be ready..."
oc wait --for=jsonpath='{.status.state}'=ready clusterpolicy gpu-cluster-policy --timeout=300s

# Phase 2: Platform Operators
echo "--- Phase 2: Deploying Platform Operators ---"

echo "3. Deploying OpenShift Serverless Operator..."
oc apply -k serverless-operator/base/
echo "   Waiting for OpenShift Serverless Operator to be ready..."
oc wait --for=condition=Ready pod -l app.kubernetes.io/name=serverless-operator -n openshift-serverless --timeout=300s

echo "4. Deploying OpenShift ServiceMesh Operator..."
oc apply -k servicemesh-operator/base/
echo "   Waiting for OpenShift ServiceMesh Operator to be ready..."
oc wait --for=condition=Ready pod -l app.kubernetes.io/name=servicemeshoperator -n openshift-operators --timeout=300s

echo "5. Deploying Authorino Operator..."
oc apply -k authorino-operator/base/
echo "   Waiting for Authorino Operator to be ready..."
oc wait --for=condition=Ready pod -l app.kubernetes.io/name=authorino-operator -n openshift-operators --timeout=300s

# Phase 3: AI Platform Operator (depends on all previous)
echo "--- Phase 3: Deploying AI Platform Operator ---"

echo "6. Deploying RHOAI Operator..."
oc apply -k rhoai-operator/base/
echo "   Waiting for RHOAI Operator to be ready..."
oc wait --for=condition=Ready pod -l app.kubernetes.io/name=rhods-operator -n redhat-ods-operator --timeout=300s

echo "   Applying RHOAI Operator Overlay (CRDs)..."
oc apply -k rhoai-operator/overlays/crds/
echo "   Waiting for DataScienceCluster to be ready..."
oc wait --for=jsonpath='{.status.conditions[?(@.type=="Ready")].status}'=True datasciencecluster default-dsc --timeout=600s

echo "=== All operators deployed successfully! ==="
echo ""
echo "Deployment Summary:"
echo "✓ NFD Operator with NFD instance (Available)"
echo "✓ NVIDIA GPU Operator with ClusterPolicy (Ready)"
echo "✓ OpenShift Serverless Operator"
echo "✓ OpenShift ServiceMesh Operator"
echo "✓ Authorino Operator"
echo "✓ RHOAI Operator with DataScienceCluster (Ready)"
echo ""
echo "Next steps and ToDos:"
echo "1. Verify RHOAI Dashboard is accessible"
echo "2. Patch OdhDashboard to enable Model Registry UI, enable training ui"
echo "3. Deploy Mariadb for Model Registry"
echo "4. Configure Model Registry for RHOAI with Mariadb"
echo "5. Enable observability for RHOAI"
echo "6. Deploy LlamaStackInstance for LlamaStack"
