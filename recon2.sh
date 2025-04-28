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

clearTerminal(){ clear; }
banner() {
    clear
    echo -e "${RED}"
    figlet -f slant "RECON 2"
    echo -e "${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${YELLOW}⚔️  Offensive Recon Script - By: ${GREEN}Pixel_DefaultBR${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo ""
}

show_help() {
    echo -e "${GREEN}Uso:${NC} $0 dominio.com [rate-limit] [--httpx] [--nuclei] [--dast]"
    echo -e "${BLUE}Flags disponíveis:${NC}"
    echo -e "  --httpx      Ativa a verificação de alvos online com httpx"
    echo -e "  --nuclei     Ativa o uso do Nuclei"
    echo -e "  --dast       Ativa testes dinâmicos no Nuclei (quando nuclei estiver ativado)"
    echo -e "  --help       Exibe esta mensagem de ajuda"
    exit 0
}

clearTerminal
banner "Recon"
START=$(date +%s)

if [[ "$1" == "--help" ]] || [[ -z "$1" ]]; then
    show_help
fi

DOMAIN=$1
RATE=${2:-50}
USE_HTTPX=false
USE_NUCLEI=false
DAST_FLAG=""

for arg in "$@"; do
    case $arg in
        --httpx)
            USE_HTTPX=true
            ;;
        --nuclei)
            USE_NUCLEI=true
            ;;
        --dast)
            DAST_FLAG="-dast"
            ;;
    esac
done

DATE=$(date +%s)
WORKDIR="/tmp/scan_${DOMAIN}_${DATE}"
mkdir -p "$WORKDIR"
cd "$WORKDIR" || { error "Não foi possível acessar o diretório de trabalho"; exit 1; }

info "🧠 Iniciando reconhecimento para: ${YELLOW}$DOMAIN${NC}"
info "🔁 Rate limit: ${YELLOW}$RATE${NC} req/s"
info "📁 Diretório de trabalho: ${WORKDIR}"

info "🔎 Coletando subdomínios com subfinder..."
subfinder -d "$DOMAIN" -silent > subdomains.txt
success "Subdomínios salvos em subdomains.txt ($(wc -l < subdomains.txt) encontrados)"

info "📦 Coletando URLs arquivadas com gau..."
cat subdomains.txt | gau --providers wayback,commoncrawl,otx,urlscan --subs > gau_output.txt
success "URLs arquivadas salvas em gau_output.txt ($(wc -l < gau_output.txt) encontradas)"

info "🔍 Filtrando URLs com parâmetros..."
grep '?' gau_output.txt | sort -u > urls_with_param.txt
success "URLs com parâmetros salvas em urls_with_param.txt ($(wc -l < urls_with_param.txt) encontradas)"

info "🔗 Unindo subdomínios e URLs..."
cat subdomains.txt gau_output.txt | sort -u > all_targets.txt
success "Alvos totais combinados: $(wc -l < all_targets.txt)"

if [ "$USE_HTTPX" = true ]; then
    info "🌐 Verificando alvos online com httpx (códigos 200)..."
    httpx -l all_targets.txt -silent -status-code -mc 200 -o live_200.txt
    cut -d' ' -f1 live_200.txt > live.txt
    success "Alvos vivos (HTTP 200): $(wc -l < live.txt)"
else
    warn "⚠️ HTTPX desativado. Nenhuma verificação de status HTTP será feita."
    cp all_targets.txt live.txt
fi

if [ "$USE_NUCLEI" = true ]; then
    info "🚨 Rodando Nuclei com templates de exposição..."
    nuclei -l live.txt -tags exposure,cve -rate-limit "$RATE" -o nuclei_exposure.txt
    success "Scan de exposure concluído (resultados em nuclei_exposure.txt)"

    if [ -n "$DAST_FLAG" ]; then
        info "🧪 DAST ativado: rodando templates completos com Nuclei..."
    else
        warn "🧪 DAST não ativado. Rodando templates padrão."
    fi

    nuclei -l urls_with_param.txt -t ~/nuclei-templates/ $DAST_FLAG -rate-limit "$RATE" -o nuclei_all_templates.txt
    success "Scan completo do Nuclei salvo em nuclei_all_templates.txt"
else
    warn "⚠️ Nuclei desativado. Nenhum scan de vulnerabilidades será executado."
fi

END=$(date +%s)
DURATION=$((END - START))
success "🎯 Finalizado em ${DURATION}s. Resultados completos em: ${WORKDIR}"
