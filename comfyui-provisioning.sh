#!/bin/bash

set -e

source /venv/main/bin/activate

COMFYUI_DIR="${WORKSPACE:-/workspace}/ComfyUI"
CUSTOM_NODES_DIR="${COMFYUI_DIR}/custom_nodes"
DIFFUSION_MODELS_DIR="${COMFYUI_DIR}/models/diffusion_models"
LORAS_DIR="${COMFYUI_DIR}/models/loras"
TEXT_ENCODERS_DIR="${COMFYUI_DIR}/models/text_encoders"
VAE_DIR="${COMFYUI_DIR}/models/vae"
FRAME_INTERP_DIR="${COMFYUI_DIR}/models/frame_interpolation"
CUSTOM_NODE_REPOS=(
    "https://github.com/kijai/ComfyUI-KJNodes.git"
    "https://github.com/MeeeyoAI/ComfyUI_StringOps.git"
    "https://github.com/obsxrver/ComfyUI-TBG-SAM3.git"
    "https://github.com/yolain/ComfyUI-Easy-Use.git"
    "https://github.com/cubiq/ComfyUI_essentials"
    "https://github.com/obsxrver/ComfyUI-MultiGPU-Orchestrator.git"
    "https://github.com/ClownsharkBatwing/RES4LYF"
)

EXTRA_PIP_PACKAGES=(
    "sageattention"
    "sam3"
    "PyOpenGL-accelerate"
)

# Entry format: target_dir|filename|url|label
MODEL_DOWNLOADS=(
    #"${DIFFUSION_MODELS_DIR}|wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors|hf://Comfy-Org/Wan_2.2_ComfyUI_Repackaged/split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors|Wan 2.2 T2V high noise model"
    #"${DIFFUSION_MODELS_DIR}|wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors|hf://Comfy-Org/Wan_2.2_ComfyUI_Repackaged/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors|Wan 2.2 T2V low noise model"
    "${DIFFUSION_MODELS_DIR}|wan2.2_i2v_high_int8_convrot.safetensors|hf://obsxrver/ComfyUI-Native-INT8_ConvRot/diffusion_models/wan2.2_i2v_high_int8_convrot.safetensors|Wan 2.2 I2V Int8ConvRot high noise model"
    "${DIFFUSION_MODELS_DIR}|wan2.2_i2v_low_int8_convrot.safetensors|hf://obsxrver/ComfyUI-Native-INT8_ConvRot/diffusion_models/wan2.2_i2v_low_int8_convrot.safetensors|Wan 2.2 I2V Int8ConvRot low noise model"
    "${TEXT_ENCODERS_DIR}|nsfw_wan_umt5-xxl_bf16_fixed.safetensors|hf://zootkitty/nsfw_wan_umt5-xxl_bf16_fixed/nsfw_wan_umt5-xxl_bf16_fixed.safetensors|UMT5 NSFW BF16 text encoder"
    "${VAE_DIR}|Wan2_1_VAE_fp32.safetensors|hf://Kijai/WanVideo_comfy/Wan2_1_VAE_fp32.safetensors|Wan 2.1 VAE FP32"
    "${FRAME_INTERP_DIR}|rife_v4.26_heavy.safetensors|hf://Comfy-Org/frame_interpolation/frame_interpolation/rife_v4.26_heavy.safetensors|Rife 4.26 Heavys"
)

LORA_DOWNLOADS=(
    #"${LORAS_DIR}|wan2.2_t2v_A14b_high_noise_lora_rank64_lightx2v_4step_1217.safetensors|hf://lightx2v/Wan2.2-Distill-Loras/wan2.2_t2v_A14b_high_noise_lora_rank64_lightx2v_4step_1217.safetensors|Wan 2.2 T2V high noise Lightning LoRA"
    #"${LORAS_DIR}|wan2.2_t2v_A14b_low_noise_lora_rank64_lightx2v_4step_1217.safetensors|hf://lightx2v/Wan2.2-Distill-Loras/wan2.2_t2v_A14b_low_noise_lora_rank64_lightx2v_4step_1217.safetensors|Wan 2.2 T2V low noise Lightning LoRA"
    "${LORAS_DIR}|wan2.2_i2v_A14b_high_noise_lora_rank64_lightx2v_4step_1022.safetensors|hf://lightx2v/Wan2.2-Distill-Loras/wan2.2_i2v_A14b_high_noise_lora_rank64_lightx2v_4step_1022.safetensors|Wan 2.2 I2V high noise Lightning LoRA"
    "${LORAS_DIR}|wan2.2_i2v_A14b_low_noise_lora_rank64_lightx2v_4step_1022.safetensors|hf://lightx2v/Wan2.2-Distill-Loras/wan2.2_i2v_A14b_low_noise_lora_rank64_lightx2v_4step_1022.safetensors|Wan 2.2 I2V low noise Lightning LoRA"
    "${LORAS_DIR}|wan2.2_i2v_A14b_low_noise_lora_lightx2v_4step_720p_260412.safetensors|hf://obsxrver/wan2.2-i2v-lightx2v-260412/wan2.2_i2v_A14b_low_noise_lora_rank64_lightx2v_4step_720p_260412.safetensors|Wan 2.2 I2V low noise Lightning LoRA 260412"
)

function provisioning_print_header() {
    printf "\n##############################################\n#                                            #\n#          Provisioning container            #\n#                                            #\n#         This will take some time           #\n#                                            #\n# Your container will be ready on completion #\n#                                            #\n##############################################\n\n"
}

function provisioning_print_end() {
    printf "\nProvisioning complete: Application will start now\n\n"
}

function provisioning_download() {
    local url="$1"
    local target_dir="$2"
    local filename="$3"
    local auth_token=""

    mkdir -p "$target_dir"

    if [[ -n $HF_TOKEN && $url =~ ^hf://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        auth_token="$HF_TOKEN"
    elif [[ -n $CIVITAI_TOKEN && $url =~ ^hf://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
        auth_token="$CIVITAI_TOKEN"
    fi
    #HF token not needed since all repos public.
    if [[ $url == hf://* ]]; then
        hf download $url --local-dir $target_dir
    elif [[ -n $auth_token ]]; then
        wget --header="Authorization: Bearer $auth_token" -qnc --show-progress -e dotbytes="4M" -O "${target_dir}/${filename}" "$url"
    else
        wget -qnc --show-progress -e dotbytes="4M" -O "${target_dir}/${filename}" "$url"
    fi
}

function update_comfyui() {
    echo "================================"
    echo "Setting up ComfyUI..."
    echo "================================"

    if [[ ! -d "${COMFYUI_DIR}" ]]; then
        echo "Error: ComfyUI directory not found at ${COMFYUI_DIR}"
        exit 1
    fi

    cd "${COMFYUI_DIR}"
    echo "Checking out master branch..."
    git checkout master
    echo "Pulling latest changes..."
    git pull
    echo "Installing/updating requirements..."
    pip install -r requirements.txt
}

function install_custom_node_requirements() {
    local node_path="$1"
    local requirements_file="${node_path}/requirements.txt"

    if [[ -f "${requirements_file}" ]]; then
        echo "Installing requirements for $(basename "${node_path}")..."
        pip install -r "${requirements_file}" --break-system-packages
    fi
}

function install_custom_node() {
    local repo="$1"
    local node_name="${repo##*/}"
    local node_dir="${node_name%.git}"
    local node_path="${CUSTOM_NODES_DIR}/${node_dir}"

    if [[ -d "${node_path}/.git" ]]; then
        if [[ ${AUTO_UPDATE,,} != "false" ]]; then
            echo "Updating ${node_dir}..."
            (
                cd "${node_path}"
                git pull
            )
        else
            echo "Skipping update for ${node_dir} because AUTO_UPDATE=false"
        fi
    else
        echo "Installing ${node_dir}..."
        git clone "${repo}" "${node_path}" --recursive
    fi

    install_custom_node_requirements "${node_path}"
}

function install_custom_nodes() {
    echo ""
    echo "================================"
    echo "Installing Custom Nodes..."
    echo "================================"

    mkdir -p "${CUSTOM_NODES_DIR}"

    local repo
    for repo in "${CUSTOM_NODE_REPOS[@]}"; do
        install_custom_node "${repo}"
    done
}

function ensure_model_directories() {
    echo ""
    echo "================================"
    echo "Creating model directories..."
    echo "================================"

    mkdir -p "${DIFFUSION_MODELS_DIR}"
    mkdir -p "${LORAS_DIR}"
    mkdir -p "${TEXT_ENCODERS_DIR}"
    mkdir -p "${VAE_DIR}"
}

function download_asset() {
    local target_dir="$1"
    local filename="$2"
    local url="$3"
    local label="$4"

    echo "Downloading ${label}..."
    provisioning_download "${url}" "${target_dir}" "${filename}"
    echo "✓ ${label} downloaded"
}

function queue_downloads() {
    local download
    for download in "$@"; do
        IFS='|' read -r target_dir filename url label <<< "${download}"
        (
            download_asset "${target_dir}" "${filename}" "${url}" "${label}"
        ) &
    done
}

function download_models() {
    if [[ -n $HF_TOKEN ]];then
        hf auth login --token $HF_TOKEN
    fi
    queue_downloads "${MODEL_DOWNLOADS[@]}"
}

function download_loras() {
    queue_downloads "${LORA_DOWNLOADS[@]}"
}

function install_extra_packages() {
    local package
    for package in "${EXTRA_PIP_PACKAGES[@]}"; do
        (
            echo "Installing ${package}..."
            uv pip install -U "${package}"
        ) &
    done
}


function install_sageattention() {
    sudo apt-get install -y nvidia-cuda-toolkit
    cd /
    git clone "https://github.com/thu-ml/SageAttention"
    cd /SageAttention
    export EXT_PARALLEL=4 NVCC_APPEND_FLAGS="--threads 8" MAX_JOBS=32 # Optional
    python setup.py install &
}

function create_start_comfyui_script() {
    cat > /workspace/start_comfyui.sh <<'EOF'
#!/bin/bash

set -e

source /venv/main/bin/activate

supervisorctl stop comfyui || true
pgrep -f main.py | xargs -r kill -9

cuda_device_count="$(python - <<'PY'
import torch

print(torch.cuda.device_count())
PY
)"

if [[ "${cuda_device_count}" -lt 1 ]]; then
    echo "No CUDA devices found"
    exit 1
fi

cd /workspace

python /workspace/ComfyUI/main.py --cuda-device 0 --port 18188 > comfyui-0.log 2>&1 &

for ((i = 1; i < cuda_device_count; i++)); do
    python /workspace/ComfyUI/main.py --cuda-device "${i}" --port "$((8188 + i))" > "comfyui-${i}.log" 2>&1 &
done
EOF

    chmod +x /workspace/start_comfyui.sh
}

function print_download_summary() {
    echo "================================"
    echo "All downloads completed successfully!"
    echo ""
    echo "Files downloaded to:"
    echo "  - Diffusion models: ${DIFFUSION_MODELS_DIR}/"
    echo "  - LoRAs: ${LORAS_DIR}/"
    echo "  - Text encoder: ${TEXT_ENCODERS_DIR}/"
    echo "  - VAE: ${VAE_DIR}/"
}

function provisioning_start() {
    
    provisioning_print_header
    #uninstall old comfyui frontend package to fix deprecated import errors.
    rm -rf "${CUSTOM_NODES_DIR}/ComfyUI-Manager" #Remove the old manager
    uv pip uninstall comfyui_frontend_package
    update_comfyui
    uv pip install -r "${COMFYUI_DIR}/manager_requirements.txt"
    install_custom_nodes
    ensure_model_directories

    create_start_comfyui_script

    echo ""
    echo "================================"
    echo "Starting parallel model downloads..."
    echo "================================"
    uv pip install -U huggingface_hub
    download_models
    download_loras
    install_extra_packages
    install_sageattention
    wait
    print_download_summary
    provisioning_print_end
}

if [[ ! -f /.noprovisioning ]]; then
    provisioning_start
fi
