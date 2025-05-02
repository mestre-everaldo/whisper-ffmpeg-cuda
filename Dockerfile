# ---------------------------------------------------------------------------
# Argumentos de Build para Flexibilidade CUDA
# ---------------------------------------------------------------------------
# Define a tag completa da imagem base nvidia/cuda a ser usada.
# (Verifique tags disponíveis em: https://hub.docker.com/r/nvidia/cuda/tags)
ARG NVIDIA_CUDA_BASE_TAG="12.8.1-cudnn-runtime-ubuntu24.04"

# Define o sufixo da wheel do PyTorch correspondente à versão CUDA da imagem base.
# (Verifique sufixos válidos em: https://pytorch.org/get-started/locally/)
# Ex: cu118, cu121, cu128
ARG PYTORCH_CUDA_SUFFIX="cu128"

# ---------------------------------------------------------------------------
# Estágio 1: Fonte do FFmpeg pré-compilado (Independente da base CUDA final)
# ---------------------------------------------------------------------------
FROM jrottenberg/ffmpeg:6.1-ubuntu-edge AS ffmpeg_source

# ---------------------------------------------------------------------------
# Estágio 2: Imagem Final de Execução com CUDA e Python
# Usa a tag da imagem base definida pelo argumento NVIDIA_CUDA_BASE_TAG
# ---------------------------------------------------------------------------
FROM nvidia/cuda:${NVIDIA_CUDA_BASE_TAG} AS final

# Re-declare ARGs se precisar usá-los DENTRO deste estágio (necessário para PYTORCH_CUDA_SUFFIX)
ARG PYTORCH_CUDA_SUFFIX

# Configurações de Ambiente Essenciais
ENV LANG="C.UTF-8"
ENV LC_ALL="C.UTF-8"
ENV DEBIAN_FRONTEND="noninteractive"
ENV PYTHONUNBUFFERED="1"

# Instala dependências mínimas do sistema
# Adaptação: Verifica se python3-pip está disponível, senão instala python3-full e pip via get-pip.py
# Isso pode ser necessário em bases muito mínimas, embora runtime geralmente tenha pip.
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    git \
    ca-certificates \
    wget \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# Cria diretórios de destino para o FFmpeg copiado
RUN mkdir -p /opt/ffmpeg/bin /opt/ffmpeg/lib

# Copia o binário FFmpeg do estágio fonte
COPY --from=ffmpeg_source /usr/local/bin/ffmpeg /opt/ffmpeg/bin/

# Copia TODAS as bibliotecas compartilhadas do FFmpeg do estágio fonte
COPY --from=ffmpeg_source /usr/local/lib/ /opt/ffmpeg/lib/

# Configura o ambiente para encontrar o FFmpeg
ENV PATH="/opt/ffmpeg/bin:${PATH}"
ENV LD_LIBRARY_PATH="/opt/ffmpeg/lib:${LD_LIBRARY_PATH}"

# Etapa de verificação: Confirma se o ffmpeg funciona
RUN ffmpeg -version

# Instala PyTorch com suporte CUDA
# Usa o sufixo PYTORCH_CUDA_SUFFIX definido pelo argumento de build.
# Adiciona --break-system-packages para compatibilidade com PEP 668 (Ubuntu >= 23.04)
RUN python3 -m pip install --no-cache-dir --break-system-packages \
    torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/${PYTORCH_CUDA_SUFFIX}

# Instala a última versão do Whisper diretamente do GitHub
# Adiciona --break-system-packages
RUN python3 -m pip install --no-cache-dir --break-system-packages \
    git+https://github.com/openai/whisper.git

# Define o diretório de trabalho padrão dentro do container
WORKDIR /app

# Define o ponto de entrada padrão para executar o comando whisper
ENTRYPOINT ["whisper"]

# Define o comando padrão (mostra a ajuda se nenhum argumento for fornecido)
CMD ["--help"]

# Restaura o modo de frontend padrão do Debian
ENV DEBIAN_FRONTEND="dialog"
