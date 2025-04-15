#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}[i]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
success() { echo -e "${GREEN}[✔]${NC} $1"; }
error() { echo -e "${RED}[x]${NC} $1"; }

START=$(date +%s)

if [ -z "$1" ]; then
    error "Uso: $0 dominio.com [rate-limit]"
    exit 1
fi

for bin in httpx subfinder gau nuclei; do
    if ! command -v "$bin" &> /dev/null; then
        error "A ferramenta $bin não foi encontrada! Verifique a instalação."
        exit 1
    fi
done

DOMAIN=$1
RATE=${2:-50}
DATE=$(date +%s)
WORKDIR="/tmp/scan_${DOMAIN}_${DATE}"
mkdir -p "$WORKDIR"
cd "$WORKDIR" || { error "Não foi possível acessar o diretório de trabalho"; exit 1; }

info "🧠 Iniciando reconhecimento para: ${YELLOW}$DOMAIN${NC}"
info "🔁 Rate limit do Nuclei: ${YELLOW}$RATE${NC} req/s"
info "📁 Diretório de trabalho: ${WORKDIR}"

info "🔎 Coletando subdomínios com subfinder..."
subfinder -d "$DOMAIN" -silent > subdomains.txt
success "Subdomínios salvos em subdomains.txt ($(wc -l < subdomains.txt) encontrados)"

info "📦 Coletando URLs arquivadas com gau..."
cat subdomains.txt | gau --providers wayback,commoncrawl,otx,urlscan --subs > gau_output.txt
success "URLs arquivadas salvas em gau_output.txt ($(wc -l < gau_output.txt) encontradas)"

info "🔗 Unindo subdomínios e URLs..."
cat subdomains.txt gau_output.txt | sort -u > all_targets.txt
success "Alvos totais combinados: $(wc -l < all_targets.txt)"

info "🌐 Verificando alvos online com httpx (códigos 200)..."
httpx -l all_targets.txt -silent -status-code -mc 200 -o live_200.txt
cut -d' ' -f1 live_200.txt > live.txt
success "Alvos vivos (HTTP 200): $(wc -l < live.txt)"

info "🚨 Rodando Nuclei com templates de exposição e misconfig..."
nuclei -l live.txt -tags exposure,misconfig -rate-limit "$RATE" -o nuclei_exposure.txt
success "Scan de exposure concluído (resultados em nuclei_exposure.txt)"

END=$(date +%s)
DURATION=$((END - START))
success "🎯 Finalizado em ${DURATION}s. Resultados completos em: ${WORKDIR}"