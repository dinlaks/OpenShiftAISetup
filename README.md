# OpenShift AI (RHOAI) Deployment Guide

This directory contains the GitOps configuration for deploying OpenShift AI operators in the correct dependency order with automated CRD deployment and status verification.

## **Prerequisites**

### **Required Infrastructure**
- **OpenShift 4.19 cluster** (tested and verified)
- **OC CLI tool** installed and configured
- **GPU-enabled nodes** (NVIDIA GPUs recommended for SLM/LLM workloads)
- **Cluster admin privileges** for operator installation
- **Internet connectivity** for operator image pulls

### **System Requirements**
- **Minimum 3 worker nodes** (recommended for production)
- **GPU nodes** with NVIDIA drivers (for ML/AI workloads)
- **Sufficient resources** for operator pods and workloads
- **Storage** for model storage and data persistence

### **GPU Spot Instance Price Script**
- Once OCP cluster and AI is installed, we can use this **scripts/gpu-config.sh** to find the best price and helps to create a machine

## **Version Compatibility**
> **⚠️ IMPORTANT**: This configuration is specifically tested for:
> - **OpenShift Container Platform 4.19**
> - **RHOAI 2.22.1**
> 
> For other OCP versions, update the NFD and NVIDIA operator overlay files accordingly.

## **Quick Start**

### **1. Clone and Navigate**
```bash
git clone https://github.com/dinlaks/OpenShiftAISetup.git
cd OpenShiftAISetup
```

### **2. Verify Prerequisites**
```bash
# Check OC CLI
oc version

# Verify cluster access
oc get nodes

# Check for GPU nodes (optional)
oc get nodes -l node-role.kubernetes.io/worker
```

### **3. Deploy All Operators**
```bash
# Make script executable
chmod +x deploy-operators.sh

# Run the deployment script
./deploy-operators.sh
```

## **Deployment Process**

The `deploy-operators.sh` script automatically handles the complete deployment process:

### **Phase 1: Infrastructure Operators**
1. **NFD Operator** - Node Feature Discovery
   - Deploys operator
   - Applies NFD instance CRD
   - Waits for `Status: Available`

2. **NVIDIA GPU Operator** - GPU management
   - Deploys operator
   - Applies ClusterPolicy CRD
   - Waits for `state: ready`

### **Phase 2: Platform Operators**
3. **OpenShift Serverless Operator** - Knative serving
4. **OpenShift ServiceMesh Operator** - Service mesh
5. **Authorino Operator** - Authentication/Authorization

### **Phase 3: AI Platform**
6. **RHOAI Operator** - OpenShift AI platform
   - Deploys operator
   - Applies DataScienceCluster CRD
   - Waits for `Status: Ready`

## **Manual Deployment (Alternative)**

If you prefer manual deployment:

```bash
# Deploy operators in order
oc apply -k nfd-operator/base/
oc apply -k nvidia-operator/base/
oc apply -k serverless-operator/base/
oc apply -k servicemesh-operator/base/
oc apply -k authorino-operator/base/
oc apply -k rhoai-operator/base/

# Apply CRDs after operators are ready
oc apply -k nfd-operator/overlays/crds/
oc apply -k nvidia-operator/overlays/crds/
oc apply -k rhoai-operator/overlays/crds/
```

## **Directory Structure**

```
OpenShiftAISetup/
├── deploy-operators.sh          # Automated deployment script
├── README.md                    # This file
├── authorino-operator/
├── nfd-operator/
├── nvidia-operator/
├── rhoai-operator/
├── serverless-operator/
└── servicemesh-operator/
    ├── base/                    # Operator subscriptions
    └── overlays/crds/           # Custom Resource Definitions
```

## **Verification**

After deployment, verify all components:

```bash
# Check operator pods
oc get pods -n openshift-nfd
oc get pods -n nvidia-gpu-operator
oc get pods -n redhat-ods-operator

# Check CRDs
oc get nfd-instance -n openshift-nfd
oc get clusterpolicy
oc get datasciencecluster

# Check GPU resources
oc describe nodes | grep nvidia.com/gpu
```

## **Accessing OpenShift AI**

1. **Get the dashboard URL**:
   ```bash
   oc get route -n redhat-ods-applications
   ```

2. **Login with OpenShift credentials**
3. **Start using Jupyter notebooks, model serving, and ML pipelines**

## **Troubleshooting**

### **Common Issues**
- **GPU not detected**: Ensure NFD instance is `Available` and GPU nodes are labeled
- **Operators not ready**: Check resource limits and node capacity
- **CRDs not applied**: Verify operator pods are running before applying overlays

### **Useful Commands**
```bash
# Check operator status
oc get csv -n openshift-nfd
oc get csv -n nvidia-gpu-operator

# View operator logs
oc logs -n openshift-nfd deployment/nfd-operator

# Check GPU resources
oc get nodes -o json | jq '.items[].status.allocatable | select(."nvidia.com/gpu")'
```

## **Next Steps**

1. **Configure authentication** (htpasswd, LDAP, etc.)
2. **Set up storage classes** for model storage
3. **Deploy your first ML model** using KServe or ModelMesh
4. **Configure monitoring** and logging
5. **Set up CI/CD pipelines** for ML workflows

# Uninstall all the deployed operators
To uninstall and clean up all the operators, use the script uninstall-operators.sh
