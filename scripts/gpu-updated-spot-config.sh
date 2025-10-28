#!/bin/sh

# This script finds the current cheapest spot price for various AWS GPU instances 
# in the us-east-2 region (Ohio) and prepares a machineset YAML file for OpenShift.

# --- Configuration ---
NUM_GPU_OPTIONS=10
DEFAULT_CHOICE=4 # New default: g6.8xlarge (Mid-Range Training)

# Check for AWS credentials
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "AWS credentials not configured. Please run 'aws configure' and follow the prompts."
    aws configure
fi

# Get cluster region and availability zone
# Note: This assumes the script is run from a worker node or has 'oc' access configured.
REGION=$(oc get nodes -o jsonpath='{.items[0].metadata.labels.topology\.kubernetes\.io/region}')
ZONE=$(oc get nodes -o jsonpath='{.items[0].metadata.labels.topology\.kubernetes\.io/zone}')

# Verify region is us-east-2, otherwise exit
if [ "$REGION" != "us-east-2" ]; then
    echo "Error: This script is configured for 'us-east-2' (Ohio), but your cluster is in $REGION."
    exit 1
fi

# Function to display instance type options and find the cheapest
show_instance_types() {
    echo "Available GPU Instance Types (Region: $REGION, Zone: $ZONE):"
    # Adjusted separator length to accommodate wider Description column
    echo "--------------------------------------------------------------------------------------------------------------------------"
    # Widened Description column from 55 to 70 characters
    printf "%-4s %-15s %-70s %-15s\n" "ID" "Instance Type" "Description" "Spot Price"
    echo "--------------------------------------------------------------------------------------------------------------------------"

    declare -a prices
    print_instance_info() {
        local id=$1
        local type=$2
        local desc=$3
        # Fetch the spot price using the utility. Grep and Tail ensure only the price value is captured.
        local price=$(spotprice -inst $type -reg $REGION -az $ZONE | grep -o '[0-9\\.]*' | tail -n 1)
        prices[$id]=$price
        # Widened Description column from 55 to 70 characters
        printf "%-4s %-15s %-70s \$%s/hour\n" "$id)" "$type" "$desc" "$price"
    }

    # --- EXPANDED GPU INSTANCE LIST (Ordered by general cost/power) ---
    print_instance_info 1 p4d.24xlarge  "8 A100 (40GB each), 96 vCPUs, 1152 GB RAM (High-End Training)"
    print_instance_info 2 g6e.48xlarge  "8 L40S GPUs, 192 vCPUs, 768 GB RAM (High-End Inference/Training)"
    print_instance_info 3 g6.12xlarge   "4 L4 GPUs, 48 vCPUs, 192 GB RAM (Mid-Range Distributed)"
    print_instance_info 4 g6.8xlarge    "1 L4 GPU (24GB), 32 vCPUs, 128 GB RAM (Requested Mid-Range/Default)"
    print_instance_info 5 g5.8xlarge    "1 A10G GPU (24GB), 32 vCPUs, 128 GB RAM (Mid-Range General Purpose)"
    print_instance_info 6 p3.8xlarge    "4 V100 GPUs, 32 vCPUs, 244 GB RAM (Legacy Training)"
    print_instance_info 7 g4dn.2xlarge  "1 T4 GPU (16GB), 8 vCPUs, 32 GB RAM (Entry-Level Inference)"
    print_instance_info 8 g5.xlarge     "1 A10G GPU (24GB), 4 vCPUs, 16 GB RAM (Lowest Cost A10G)"
    print_instance_info 9 g4dn.xlarge   "1 T4 GPU (16GB), 4 vCPUs, 16 GB RAM (Lowest Cost T4)"
    print_instance_info 10 g4ad.xlarge  "1 AMD Radeon Pro V520, 4 vCPUs, 16 GB RAM (AMD Graphics Option)"
    echo "--------------------------------------------------------------------------------------------------------------------------"

    # --- Cheapest Price Calculation ---
    local cheapest_id=0
    local cheapest_price=""

    # Find the first available price to initialize comparison
    for i in $(seq 1 $NUM_GPU_OPTIONS); do
        if [ -n "${prices[$i]}" ] && [ "${prices[$i]}" != "0" ]; then
            cheapest_id=$i
            cheapest_price=${prices[$i]}
            break
        fi
    done

    # If we found a price, loop through the rest to find the cheapest
    if [ "$cheapest_id" -ne 0 ]; then
        i=$(expr $cheapest_id + 1)
        while [ $i -le $NUM_GPU_OPTIONS ]; do
            # Use 'bc' for floating-point comparison
            if [ -n "${prices[$i]}" ] && [ "$(echo "${prices[$i]} < $cheapest_price" | bc)" = "1" ]; then
                cheapest_price=${prices[$i]}
                cheapest_id=$i
            fi
            i=$(expr $i + 1)
        done
        echo "Suggestion: The cheapest available instance is #$cheapest_id at \$${prices[$cheapest_id]}/hour."
    else
        echo "Suggestion: No spot prices available or instance types not currently offered in $REGION/$ZONE."
    fi
    echo ""
}

# Function to get instance type based on selection
get_instance_type() {
    case $1 in
        1) echo "p4d.24xlarge" ;;
        2) echo "g6e.48xlarge" ;;
        3) echo "g6.12xlarge" ;;
        4) echo "g6.8xlarge" ;;
        5) echo "g5.8xlarge" ;;
        6) echo "p3.8xlarge" ;;
        7) echo "g4dn.2xlarge" ;;
        8) echo "g5.xlarge" ;;
        9) echo "g4dn.xlarge" ;;
        10) echo "g4ad.xlarge" ;;
        *) echo "g6.8xlarge" ;; # default
    esac
}

# Function to get GPU description for naming (used in machine set naming)
get_gpu_description() {
    case $1 in
        1) echo "a100" ;;
        2) echo "l40s" ;;
        3) echo "l4" ;;
        4) echo "l4" ;;
        5) echo "a10g" ;;
        6) echo "v100" ;;
        7) echo "t4" ;;
        8) echo "a10g" ;;
        9) echo "t4" ;;
        10) echo "amd" ;;
        *) echo "l4" ;; # default
    esac
}

# Function to get storage size based on instance type
get_storage_size() {
    # Large training instances require more space for models/data
    case $1 in
        1) echo "1500" ;;  # P4d
        2|3|4|5|6) echo "1000" ;; # G6e, G6, G5, P3
        *) echo "500" ;;   # default 500GB for others
    esac
}

# Check if instance type is provided as argument
if [ "$1" != "" ]; then
    CHOICE=$1
else
    # Interactive mode
    show_instance_types
    echo -n "Select instance type (1-$NUM_GPU_OPTIONS) [$DEFAULT_CHOICE]: "
    read CHOICE
    if [ "$CHOICE" = "" ]; then
        CHOICE=$DEFAULT_CHOICE
    fi
fi

# Validate choice
if [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt $NUM_GPU_OPTIONS ]; then
    echo "Invalid choice. Using default (ID $DEFAULT_CHOICE)"
    CHOICE=$DEFAULT_CHOICE
fi

SELECTED_INSTANCE_TYPE=$(get_instance_type $CHOICE)
GPU_DESC=$(get_gpu_description $CHOICE)
STORAGE_SIZE=$(get_storage_size $CHOICE)

echo "Selected instance type: $SELECTED_INSTANCE_TYPE"
echo "GPU description: $GPU_DESC"
echo "Storage size: ${STORAGE_SIZE}GB"
echo ""

# Get the base machineset name (assumes a standard worker machineset exists in the zone)
MS_NAME=$(oc get machinesets -n openshift-machine-api | grep "${ZONE}" | head -n1 | awk '{print $1}')

if [ -z "$MS_NAME" ]; then
    echo "Error: Could not find a base machineset in zone $ZONE to use as a template."
    echo "Please ensure there is a standard worker machineset available (e.g., 'aws-us-east-2a-worker')."
    exit 1
fi

# GPU MS name with dynamic GPU description
MS_NAME_GPU="${MS_NAME}-gpu-${GPU_DESC}"

echo "Using base machineset: $MS_NAME"
echo "Extracting current machineset configuration..."

# Use a temporary file for the machineset modification
oc get machineset $MS_NAME -n openshift-machine-api -o yaml > gpu-ms.yaml

# Get Current Instance Type
INSTANCE_TYPE=$(yq eval '.spec.template.spec.providerSpec.value.instanceType' gpu-ms.yaml)

echo "Current instance type: $INSTANCE_TYPE"
echo "Changing to: $SELECTED_INSTANCE_TYPE"

# --- Modify the machineset YAML ---

# 1. Change the name of MS
# Note: Using sed with -i.bak for portability, creating a backup file
sed -i .bak "s/${MS_NAME}/${MS_NAME_GPU}/g" gpu-ms.yaml

# 2. Change instance type to selected GPU instance
sed -i .bak "s/${INSTANCE_TYPE}/${SELECTED_INSTANCE_TYPE}/g" gpu-ms.yaml

# 3. Increase the instance volume based on instance type
sed -i .bak "s/volumeSize: 100/volumeSize: ${STORAGE_SIZE}/g" gpu-ms.yaml

# 4. Set Replica as 1
sed -i .bak "s/replicas: 0/replicas: 1/g" gpu-ms.yaml

# 5. Remove unnecessary status/metadata fields (optional cleanup)
yq eval 'del(.metadata.creationTimestamp, .metadata.resourceVersion, .metadata.uid, .metadata.annotations."kubectl.kubernetes.io/last-applied-configuration", .status)' -i gpu-ms.yaml

# 6. Inject the spot market option (OpenShift Machine API uses this annotation for Spot)
yq eval '.spec.template.metadata.labels += {"machine.openshift.io/capacity-type": "spot"}' -i gpu-ms.yaml
yq eval '.spec.template.metadata.annotations += {"machine.openshift.io/spot-max-price": ""}' -i gpu-ms.yaml

echo "Configuration updated successfully!"
echo "Machine set name: $MS_NAME_GPU"
echo "Instance type: $SELECTED_INSTANCE_TYPE"
echo "Storage size: ${STORAGE_SIZE}GB"
echo "Spot instance flag added."
echo ""
echo "----------------------------------------------------------------------------------"
echo "To create the machine set and provision the Spot GPU node, run:"
echo "oc create -f gpu-ms.yaml"
echo ""
echo "To check machine status, run:"
echo "oc get machine -n openshift-machine-api"
echo "----------------------------------------------------------------------------------"
