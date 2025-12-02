#!/usr/bin/env bash
set -e

echo "🔍 Checking Docker environment for multi-architecture builds..."

# 检查 Docker 是否存在
check_docker() {
    if command -v docker &> /dev/null; then
        echo "✅ Docker is installed"
        docker --version
    else
        echo "❌ Docker is not installed"
        exit 1
    fi
}

# 检查 Docker Compose 是否存在
check_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        echo "✅ Docker Compose is installed"
        docker-compose --version
    else
        echo "⚠️ Docker Compose is not installed, checking Docker Compose Plugin..."
        if docker compose version &> /dev/null; then
            echo "✅ Docker Compose Plugin is available"
        else
            echo "ℹ️ Docker Compose not available (not required for CI builds)"
        fi
    fi
}

# 检查 Docker Buildx 是否存在并配置
check_docker_buildx() {
    if docker buildx version &> /dev/null; then
        echo "✅ Docker Buildx is installed"
        docker buildx version

        # 检查当前 Buildx 实例
        echo "📋 Available Buildx builders:"
        docker buildx ls

        # 创建或使用现有的 builder 实例
        if ! docker buildx inspect --bootstrap &> /dev/null; then
            echo "🛠️ Creating new Buildx builder instance..."
            docker buildx create --name multiarch --use --bootstrap
        fi

        # 检查多架构支持
        echo "🔍 Checking multi-architecture support..."
        local current_builder
        current_builder=$(docker buildx inspect --bootstrap | grep "Platforms:" || true)
        echo "📊 Builder capabilities: $current_builder"

    else
        echo "❌ Docker Buildx is not installed"
        exit 1
    fi
}

# 检查 QEMU 支持（用于多架构构建）
check_qemu_support() {
    echo "🔍 Checking QEMU static binary support..."

    # 检查 binfmt 支持
    if [ -f /proc/sys/fs/binfmt_misc/qemu-aarch64 ]; then
        echo "✅ QEMU AArch64 support is enabled"
        cat /proc/sys/fs/binfmt_misc/qemu-aarch64
    else
        echo "⚠️ QEMU AArch64 support not found in binfmt_misc"
    fi

    # 检查是否可以通过 Docker 运行 QEMU 注册
    if docker run --rm --privileged tonistiigi/binfmt:latest --version &> /dev/null; then
        echo "✅ QEMU binfmt installation tool is available"
    else
        echo "⚠️ QEMU binfmt installation tool not available"
    fi
}

# 安装 QEMU 多架构支持
install_qemu_support() {
    echo "🚀 Installing QEMU multi-architecture support..."

    # 使用 tonistiigi/binfmt（更现代的方式）
    echo "Installing binfmt support for all architectures..."
    if docker run --rm --privileged tonistiigi/binfmt:latest --install all; then
        echo "✅ binfmt support installed successfully"
    else
        echo "❌ Failed to install binfmt support"
        return 1
    fi

    # 验证安装
    echo "🔍 Verifying QEMU installation..."
    if [ -f /proc/sys/fs/binfmt_misc/qemu-aarch64 ]; then
        echo "✅ QEMU AArch64 support verified"
        return 0
    else
        echo "❌ QEMU support verification failed"
        return 1
    fi
}

# 检查构建环境资源
check_system_resources() {
    echo "🔍 Checking system resources..."

    # 检查磁盘空间
    local available_disk
    available_disk=$(df -h /var/lib/docker 2>/dev/null | tail -1 | awk '{print $4}' || echo "N/A")
    echo "💾 Available Docker disk space: $available_disk"

    # 检查内存
    local available_mem
    available_mem=$(free -h | grep Mem: | awk '{print $7}')
    echo "🧠 Available memory: $available_mem"

    # 检查 CPU
    local cpu_cores
    cpu_cores=$(nproc)
    echo "⚡ CPU cores: $cpu_cores"
}

# 准备构建环境
prepare_build_environment() {
    echo "🛠️ Preparing build environment..."

    # 确保使用正确的 builder
    if ! docker buildx use default &> /dev/null && ! docker buildx use multiarch &> /dev/null; then
        echo "📦 Creating new Buildx builder..."
        docker buildx create --name multiarch --use --bootstrap
    fi

    # 检查并安装 QEMU 支持（如果需要）
    if [ ! -f /proc/sys/fs/binfmt_misc/qemu-aarch64 ]; then
        echo "📥 QEMU support missing, installing..."
        install_qemu_support || echo "⚠️ QEMU installation failed, but continuing..."
    fi

    # 验证多架构构建能力
    echo "🔍 Verifying multi-architecture build capability..."
    if docker buildx inspect --bootstrap | grep -q "linux/arm64"; then
        echo "✅ ARM64 build capability confirmed"
    else
        echo "⚠️ ARM64 build capability not detected"
    fi
}

# 主函数
main() {
    echo "=== Docker Multi-Architecture Build Environment Check ==="

    # 检查基础组件
    check_docker
    check_docker_compose
    check_docker_buildx

    # 检查系统资源
    check_system_resources

    # 检查 QEMU 支持
    check_qemu_support

    # 准备构建环境
    prepare_build_environment

    echo ""
    echo "🎉 Environment is ready for multi-architecture Docker builds!"
    echo "📋 Final builder status:"
    docker buildx ls

    echo ""
    echo "💡 Build command example:"
    echo "   docker buildx build --platform linux/amd64,linux/arm64 -t your-image:tag --push ."
}

# 运行主函数
main "$@"