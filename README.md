# OpenShift AI deployment plan

This directory contains the GitOps configuration for deploying OpenShift AI operators in the correct dependency order.

## **NOTE**: This is currently only aaplicable for OCP 4.19 and RHOAI 2.22.1. If you want to use it for any other versions of OCP make sure to update nfd and nvidia operator overlay files. In future I will try to parmeterize it when NFD and Nvidia operators are stable with OCP versions.

## Operator Deployment Order

1. **NFD Operator** - Node Feature Discovery (openshift-nfd namespace)
2. **NVIDIA Operator** - GPU Operator (nvidia-gpu-operator namespace)
3. **OpenShift Serverless Operator** (openshift-serverless namespace)
4. **OpenShift ServiceMesh Operator** (openshift-operators namespace)
5. **Authorino Operator** (openshift-operators namespace)
6. **RHOAI Operator** (redhat-ods-operator namespace)

## Directory Structure

Each operator has its own directory with the following structure:
```
operator-name/
├── base/
│   ├── namespace.yaml
│   ├── operatorgroup.yaml
│   └── subscription.yaml
└── overlays/
    └── crds/
        └── (operator-specific CRDs)
```

## Deployment Instructions

1. Apply operators in dependency order using `OC apply -k` or your preferred GitOps tool
2. Wait for each operator to be ready before proceeding to the next
3. Apply CRDs from the overlays directory after the operator is ready

## Notes

- NFD and NVIDIA operators must be installed first as they provide infrastructure capabilities
- ServiceMesh and Authorino operators share the openshift-operators namespace
- RHOAI operator requires all previous operators to be ready
