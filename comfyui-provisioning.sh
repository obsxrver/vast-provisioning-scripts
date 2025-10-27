#!/bin/bash

source /venv/main/bin/activate
COMFYUI_DIR=${WORKSPACE}/ComfyUI

# Packages are installed after nodes so we can fix them...

APT_PACKAGES=(
    #"package-1"
    #"package-2"
)

PIP_PACKAGES=(
    #"package-1"
    #"package-2"
)

NODES=(
    #"https://github.com/ltdrdata/ComfyUI-Manager"
    #"https://github.com/cubiq/ComfyUI_essentials"
)

WORKFLOWS=(

)

CHECKPOINT_MODELS=(
)

UNET_MODELS=(
)

LORA_MODELS=(
)

VAE_MODELS=(
)

ESRGAN_MODELS=(
)

CONTROLNET_MODELS=(
)

### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###

function provisioning_start() {
    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_get_nodes
    provisioning_get_pip_packages
    provisioning_get_files \
        "${COMFYUI_DIR}/models/checkpoints" \
        "${CHECKPOINT_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/unet" \
        "${UNET_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/lora" \
        "${LORA_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/controlnet" \
        "${CONTROLNET_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/vae" \
        "${VAE_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/esrgan" \
        "${ESRGAN_MODELS[@]}"
    provisioning_print_end
}

function provisioning_get_apt_packages() {
    if [[ -n $APT_PACKAGES ]]; then
            sudo $APT_INSTALL ${APT_PACKAGES[@]}
    fi
}

function provisioning_get_pip_packages() {
    if [[ -n $PIP_PACKAGES ]]; then
            pip install --no-cache-dir ${PIP_PACKAGES[@]}
    fi
}

function provisioning_get_nodes() {
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"
        path="${COMFYUI_DIR}custom_nodes/${dir}"
        requirements="${path}/requirements.txt"
        if [[ -d $path ]]; then
            if [[ ${AUTO_UPDATE,,} != "false" ]]; then
                printf "Updating node: %s...\n" "${repo}"
                ( cd "$path" && git pull )
                if [[ -e $requirements ]]; then
                   pip install --no-cache-dir -r "$requirements"
                fi
            fi
        else
            printf "Downloading node: %s...\n" "${repo}"
            git clone "${repo}" "${path}" --recursive
            if [[ -e $requirements ]]; then
                pip install --no-cache-dir -r "${requirements}"
            fi
        fi
    done
}

function provisioning_get_files() {
    if [[ -z $2 ]]; then return 1; fi
    
    dir="$1"
    mkdir -p "$dir"
    shift
    arr=("$@")
    printf "Downloading %s model(s) to %s...\n" "${#arr[@]}" "$dir"
    for url in "${arr[@]}"; do
        printf "Downloading: %s\n" "${url}"
        provisioning_download "${url}" "${dir}"
        printf "\n"
    done
}

function provisioning_print_header() {
    printf "\n##############################################\n#                                            #\n#          Provisioning container            #\n#                                            #\n#         This will take some time           #\n#                                            #\n# Your container will be ready on completion #\n#                                            #\n##############################################\n\n"
}

function provisioning_print_end() {
    printf "\nProvisioning complete:  Application will start now\n\n"
}

function provisioning_has_valid_hf_token() {
    [[ -n "$HF_TOKEN" ]] || return 1
    url="https://huggingface.co/api/whoami-v2"

    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $HF_TOKEN" \
        -H "Content-Type: application/json")

    # Check if the token is valid
    if [ "$response" -eq 200 ]; then
        return 0
    else
        return 1
    fi
}

function provisioning_has_valid_civitai_token() {
    [[ -n "$CIVITAI_TOKEN" ]] || return 1
    url="https://civitai.com/api/v1/models?hidden=1&limit=1"

    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $CIVITAI_TOKEN" \
        -H "Content-Type: application/json")

    # Check if the token is valid
    if [ "$response" -eq 200 ]; then
        return 0
    else
        return 1
    fi
}

# Download from $1 URL to $2 file path
function provisioning_download() {
    if [[ -n $HF_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        auth_token="$HF_TOKEN"
    elif 
        [[ -n $CIVITAI_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
        auth_token="$CIVITAI_TOKEN"
    fi
    if [[ -n $auth_token ]];then
        wget --header="Authorization: Bearer $auth_token" -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    else
        wget -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    fi
}

# Allow user to disable provisioning if they started with a script they didn't want
if [[ ! -f /.noprovisioning ]]; then
    provisioning_start
    #!/bin/bash

# Wan 2.2 ComfyUI Setup and Model Download Script
# Sets up ComfyUI, installs custom nodes, and downloads models in parallel

set -e

BASE_DIR="/workspace/ComfyUI"

echo "================================"
echo "Setting up ComfyUI..."
echo "================================"

# Navigate to ComfyUI directory and update
if [ -d "${BASE_DIR}" ]; then
    cd "${BASE_DIR}"
    echo "Checking out master branch..."
    git checkout master
    echo "Pulling latest changes..."
    git pull
    echo "Installing/updating requirements..."
    pip install -r requirements.txt
else
    echo "Error: ComfyUI directory not found at ${BASE_DIR}"
    exit 1
fi

echo ""
echo "================================"
echo "Installing Custom Nodes..."
echo "================================"

# Create custom_nodes directory if it doesn't exist
mkdir -p "${BASE_DIR}/custom_nodes"
cd "${BASE_DIR}/custom_nodes"

# Install ComfyUI-Distributed
if [ -d "ComfyUI-Distributed" ]; then
    echo "Updating ComfyUI-Distributed..."
    cd ComfyUI-Distributed
    git pull
    cd ..
else
    echo "Installing ComfyUI-Distributed..."
    git clone https://github.com/obsxrver/ComfyUI-Distributed.git
fi

# Install ComfyUI-KJNodes
if [ -d "ComfyUI-KJNodes" ]; then
    echo "Updating ComfyUI-KJNodes..."
    cd ComfyUI-KJNodes
    git pull
    cd ..
else
    echo "Installing ComfyUI-KJNodes..."
    git clone https://github.com/kijai/ComfyUI-KJNodes.git
fi

# Install ComfyUI_StringOps
if [ -d "ComfyUI_StringOps" ]; then
    echo "Updating ComfyUI_StringOps..."
    cd ComfyUI_StringOps
    git pull
    cd ..
else
    echo "Installing ComfyUI_StringOps..."
    git clone https://github.com/MeeeyoAI/ComfyUI_StringOps
fi

# Install requirements for custom nodes if they exist
for node_dir in ComfyUI-Distributed ComfyUI-KJNodes ComfyUI_StringOps; do
    if [ -f "${node_dir}/requirements.txt" ]; then
        echo "Installing requirements for ${node_dir}..."
        pip install -r "${node_dir}/requirements.txt" --break-system-packages
    fi
done

echo ""
echo "================================"
echo "Creating model directories..."
echo "================================"

# Create directories if they don't exist
mkdir -p "${BASE_DIR}/models/diffusion_models"
mkdir -p "${BASE_DIR}/models/loras"
mkdir -p "${BASE_DIR}/models/text_encoders"
mkdir -p "${BASE_DIR}/models/vae"

echo ""
echo "================================"
echo "Starting parallel model downloads..."
echo "================================"

# Download diffusion models
(
    echo "Downloading wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors..."
    wget -O "${BASE_DIR}/models/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors" \
        "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors?download=true"
    echo "✓ High noise model downloaded"
) &

(
    echo "Downloading wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors..."
    wget -O "${BASE_DIR}/models/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors" \
        "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors?download=true"
    echo "✓ Low noise model downloaded"
) &

# Download Lightning LoRAs
(
    echo "Downloading Wan2.2-Lightning high_noise_model.safetensors..."
    wget -O "${BASE_DIR}/models/loras/wan2.2_lightning_high_noise_model.safetensors" \
        "https://huggingface.co/lightx2v/Wan2.2-Lightning/resolve/main/Wan2.2-T2V-A14B-4steps-lora-250928/high_noise_model.safetensors?download=true"
    echo "✓ High noise Lightning LoRA downloaded"
) &

(
    echo "Downloading Wan2.2-Lightning low_noise_model.safetensors..."
    wget -O "${BASE_DIR}/models/loras/wan2.2_lightning_low_noise_model.safetensors" \
        "https://huggingface.co/lightx2v/Wan2.2-Lightning/resolve/main/Wan2.2-T2V-A14B-4steps-lora-250928/low_noise_model.safetensors?download=true"
    echo "✓ Low noise Lightning LoRA downloaded"
) &

# Download text encoder
(
    echo "Downloading umt5_xxl_fp8_e4m3fn_scaled.safetensors..."
    wget -O "${BASE_DIR}/models/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
        "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors?download=true"
    echo "✓ Text encoder downloaded"
) &

# Download VAE
(
    echo "Downloading wan_2.1_vae.safetensors..."
    wget -O "${BASE_DIR}/models/vae/wan_2.1_vae.safetensors" \
        "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors?download=true"
    echo "✓ VAE downloaded"
) &


(
    git clone https://github.com/thu-ml/SageAttention.git
    cd SageAttention 
    export EXT_PARALLEL=4 NVCC_APPEND_FLAGS="--threads 8" MAX_JOBS=32 # parallel compiling (Optional)
    python setup.py install 
) &

# Wait for all downloads to complete
wait

echo "================================"
echo "All downloads completed successfully!"
echo ""
echo "Files downloaded to:"
echo "  - Diffusion models: ${BASE_DIR}/models/diffusion_models/"
echo "  - LoRAs: ${BASE_DIR}/models/loras/"
echo "  - Text encoder: ${BASE_DIR}/models/text_encoders/"
echo "  - VAE: ${BASE_DIR}/models/vae/"

fi
