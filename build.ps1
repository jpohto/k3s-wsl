param(
    [string]$BuilderName
)

$rootfs = Join-Path $PSScriptRoot "deb-trixie-rootfs.tar.gz"
if (-not (Test-Path $rootfs)) {
    Invoke-WebRequest `
        -Uri "https://raw.githubusercontent.com/debuerreotype/docker-debian-artifacts/dist-amd64/trixie/oci/blobs/rootfs.tar.gz" `
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
    }

    $env:SCRIPT_DIR = $PSScriptRoot
    $env:WSLENV = "SCRIPT_DIR/p"

    wsl -d $builder -u root -- bash -c @'
set -euox pipefail

apt-get update
apt-get install -y ca-certificates podman

mkdir -p ./dist

podman build -t k3s-wsl:0.1 -f Dockerfile.base .
podman create --name wsl-export-container k3s-wsl:0.1
podman export wsl-export-container -o /tmp/k3s-rootfs.tar
podman rm wsl-export-container
gzip -c /tmp/k3s-rootfs.tar > ./dist/k3s-rootfs.tar.gz

podman build -t k3s-wsl:0.1-nvidia -f Dockerfile.nvidia .
podman create --name wsl-export-container-nvidia k3s-wsl:0.1-nvidia
podman export wsl-export-container-nvidia -o /tmp/k3s-nvidia-rootfs.tar
podman rm wsl-export-container-nvidia
gzip -c /tmp/k3s-nvidia-rootfs.tar > ./dist/k3s-nvidia-rootfs.tar.gz
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
