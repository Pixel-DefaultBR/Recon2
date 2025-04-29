#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

success() { echo -e "${GREEN}[✔]${NC} $1"; }
error() { echo -e "${RED}[x]${NC} $1"; }
info() { echo -e "${YELLOW}[i]${NC} $1"; }

info "Atualizando pacotes e instalando dependências básicas..."
sudo apt update && sudo apt install -y git curl wget python3-pip figlet

if ! command -v go &>/dev/null; then
    error "Go não encontrado. Instalando Go..."
    wget https://go.dev/dl/go1.22.2.linux-amd64.tar.gz -O go.tar.gz
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf go.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    export PATH=$PATH:/usr/local/go/bin
    source ~/.bashrc
    rm go.tar.gz
else
    success "Go já está instalado."
fi

GOPATH_BIN=$(go env GOPATH)/bin
mkdir -p "$GOPATH_BIN"
export PATH=$PATH:$GOPATH_BIN

info "Instalando ferramentas com Go..."

go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install github.com/projectdiscovery/httpx/cmd/httpx@latest
go install github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest
go install github.com/projectdiscovery/dnsx/cmd/dnsx@latest
go install github.com/projectdiscovery/katana/cmd/katana@latest
go install github.com/tomnomnom/waybackurls@latest
go install github.com/lc/gau/v2/cmd/gau@latest

success "Ferramentas Go instaladas com sucesso."

if [[ ":$PATH:" != *":$GOPATH_BIN:"* ]]; then
    echo 'export PATH=$PATH:'"$GOPATH_BIN" >> ~/.bashrc
    source ~/.bashrc
fi

SCRIPT_NAME="recon2.sh"
if [ -f "$SCRIPT_NAME" ]; then
    chmod +x "$SCRIPT_NAME"
    success "$SCRIPT_NAME agora é executável (chmod +x aplicado)."
else
    warn "$SCRIPT_NAME não encontrado no diretório atual. Pulei o chmod."
fi

success "Instalação concluída! Abra um novo terminal ou rode 'source ~/.bashrc' para garantir que o PATH esteja atualizado."
