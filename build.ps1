param(
    [string]$BuilderName
)

$rootfs = Join-Path $PSScriptRoot "deb-bookworm-rootfs.tar.gz"
if (-not (Test-Path $rootfs)) {
    Invoke-WebRequest `
        -Uri "https://raw.githubusercontent.com/debuerreotype/docker-debian-artifacts/dist-amd64/bookworm/oci/blobs/rootfs.tar.gz" `
        -OutFile $rootfs
}

$temporaryBuilder = [string]::IsNullOrWhiteSpace($BuilderName)
if ($temporaryBuilder) {
    $builder = "temp-wsl-" + [guid]::NewGuid().ToString("N")
}
else {
    $builder = $BuilderName
}

try {
    # Create only if it doesn't already exist
    $existing = wsl --list --quiet |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -eq $builder }

    if (-not $existing) {
        Write-Host "Creating builder distro '$builder'..."

        wsl --install `
            --name $builder `
            --from-file $rootfs `
            --no-launch

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create builder WSL '$builder'"
        }

        wsl -d $builder -u root -- bash -c @'
set -euo pipefail

apt-get update
apt-get install -y curl tar

curl -fL \
    "https://github.com/containerd/nerdctl/releases/download/v2.3.5/nerdctl-full-2.3.5-linux-amd64.tar.gz" \
    | tar -xz -C /usr/local
'@

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to initialize builder WSL '$builder'"
        }
    }
    else {
        Write-Host "Reusing builder distro '$builder'..."
    }

    $env:SCRIPT_DIR = $PSScriptRoot
    $env:WSLENV = "SCRIPT_DIR/p"

    wsl -d $builder -u root -- bash -c @'
set -euo pipefail

echo "Building inside WSL... $SCRIPT_DIR"

containerd >/tmp/containerd.log 2>&1 &

buildkitd \
    --oci-worker=false \
    --containerd-worker=true \
    --containerd-worker-namespace=default \
    >/tmp/buildkitd.log 2>&1 &

for i in {1..30}; do
    nerdctl info >/dev/null 2>&1 && break
    sleep 1
done

nerdctl info >/dev/null 2>&1 || {
    echo "containerd failed to become ready"
    cat /tmp/containerd.log
    exit 1
}

mkdir -p "$SCRIPT_DIR/dist"

nerdctl rm -f rootfs-temp >/dev/null 2>&1 || true
nerdctl build "$SCRIPT_DIR" -f Dockerfile.base -t k3s-wsl:0.1
nerdctl create --name rootfs-temp k3s-wsl:0.1
nerdctl export rootfs-temp -o "$SCRIPT_DIR/dist/k3s-rootfs.tar"

nerdctl rm -f rootfs-temp >/dev/null 2>&1 || true
nerdctl build "$SCRIPT_DIR" -f Dockerfile.nvidia -t k3s-wsl:0.1-nvidia
nerdctl create --name rootfs-temp k3s-wsl:0.1-nvidia
nerdctl export rootfs-temp -o "$SCRIPT_DIR/dist/k3s-nvidia-rootfs.tar"
'@

    if ($LASTEXITCODE -ne 0) {
        throw "Build failed"
    }
}
finally {
    if ($temporaryBuilder) {
        Write-Host "Removing temporary builder '$builder'..."
        wsl --terminate $builder 2>$null
        wsl --unregister $builder 2>$null
    }
    else {
        Write-Host "Keeping builder '$builder' for reuse."
    }
}
