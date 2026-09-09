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
    }

    $env:SCRIPT_DIR = $PSScriptRoot
    $env:WSLENV = "SCRIPT_DIR/p"

    wsl -d $builder -u root -- bash -c @'
set -euox pipefail

set -euo pipefail

apt-get update
apt-get install -y curl tar socat

if [[ -z "$(command -v buildkitd)" ]]; then
    echo "installing buildkit..."
    curl -fL \
        "https://github.com/moby/buildkit/releases/download/v0.33.0/buildkit-v0.33.0.linux-amd64.tar.gz" \
        | tar -xz -C /usr/local
fi

echo "starting buildkitd in the background..."
buildkitd > /tmp/buildkitd.log 2>&1 &

for i in {1..30}; do
    socat /dev/nul UNIX-CONNECT:/run/buildkit/buildkitd.sock 2>/dev/null && break
    echo "waiting for buildkitd socket..."
    sleep 1
done

mkdir -p ./dist
buildctl b \
  --frontend dockerfile.v0 \
  --local context=. \
  --local dockerfile=. \
  --opt target=base \
  --output type=tar | gzip > ./dist/k3s-rootfs.tar.gz

buildctl b \
  --frontend dockerfile.v0 \
  --local context=. \
  --local dockerfile=. \
  --opt target=nvidia \
  --output type=tar | gzip > ./dist/k3s-nvidia-rootfs.tar.gz
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
