# Container Docker com FFmpeg, CUDA e OpenAI Whisper

Este repositório contém um Dockerfile para construir uma imagem Docker otimizada para transcrever áudio/vídeo usando a biblioteca **OpenAI Whisper**, acelerada por **GPU NVIDIA (CUDA)**, e com suporte a diversos formatos de mídia via **FFmpeg**.

A imagem é construída usando multi-stage builds para manter o tamanho final gerenciável, copiando o FFmpeg pré-compilado de uma imagem confiável (`jrottenberg/ffmpeg`) e instalando o PyTorch com suporte CUDA específico para a versão da imagem base da NVIDIA.

## Conteúdo da Imagem

*   Sistema Base: Ubuntu (versão varia com a tag CUDA base)
*   CUDA Toolkit & CuDNN (versão varia com a tag base `nvidia/cuda`)
*   FFmpeg (versão copiada de `jrottenberg/ffmpeg:6.1-ubuntu-edge` neste Dockerfile)
*   Python 3 com Pip
*   PyTorch (compilado com suporte à versão CUDA correspondente)
*   OpenAI Whisper (instalado via pip do repositório oficial)

## Como Construir a Imagem

A imagem usa argumentos de build (`ARG`) para flexibilidade na escolha da versão CUDA da imagem base NVIDIA e do PyTorch.

1.  Clone ou baixe o Dockerfile.
2.  Abra um terminal no diretório do Dockerfile.
3.  Construa a imagem, especificando a tag da base CUDA e o sufixo do PyTorch que sejam compatíveis com o **driver NVIDIA instalado no seu sistema host**. (Use `nvidia-smi` no seu host para verificar a "CUDA Version" suportada pelo seu driver).

    ```bash
    # Sintaxe geral do build com argumentos
    # Substitua NVIDIA_CUDA_BASE_TAG e PYTORCH_CUDA_SUFFIX pelos valores compatíveis com seu driver
    # Escolha uma <tag> apropriada (ex: 12.1.1, 12.8.1)

    docker build \
      --build-arg NVIDIA_CUDA_BASE_TAG="<tag_da_base_nvidia_cuda>" \
      --build-arg PYTORCH_CUDA_SUFFIX="<sufixo_pytorch_cuda>" \
      -t everaldo/whisper-ffmpeg-cuda:<tag> .
    ```

    **Exemplos de Build:**

    *   Para Driver Host compatível com CUDA 12.1 (Base Ubuntu 22.04, PyTorch cu121):
        ```bash
        docker build \
          --build-arg NVIDIA_CUDA_BASE_TAG="12.1.1-cudnn8-runtime-ubuntu22.04" \
          --build-arg PYTORCH_CUDA_SUFFIX="cu121" \
          -t everaldo/whisper-ffmpeg-cuda:12.1.1 .
        ```
    *   Para Driver Host compatível com CUDA 12.8 (Base Ubuntu 24.04, PyTorch cu128):
        ```bash
        docker build \
          --build-arg NVIDIA_CUDA_BASE_TAG="12.8.1-cudnn-runtime-ubuntu24.04" \
          --build-arg PYTORCH_CUDA_SUFFIX="cu128" \
          -t everaldo/whisper-ffmpeg-cuda:12.8.1 .
        ```

## Como Executar o Container

O container é configurado com `ENTRYPOINT ["whisper"]`. Use a flag `--gpus all` para habilitar a aceleração via GPU. É **altamente recomendado** montar um volume para acessar seus arquivos de áudio/vídeo e para persistir o cache do modelo Whisper.

1.  Instale o [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) no seu sistema host.
2.  Tenha seu arquivo de áudio/vídeo (ex: `meu_audio.mp3`) em um diretório no seu host.
3.  Execute o comando `docker run`:

    ```bash
    # No diretório que contém seu arquivo de áudio/vídeo (Linux/macOS/WSL):
    # Substitua <tag> pela tag correta da imagem
    # Substitua meu_audio.mp3 e <opções_whisper>
    docker run \
      --rm \
      --gpus all \
      -v "$(pwd):/app" \
      -v "$HOME/.cache/whisper:/root/.cache/whisper" \  # Monta o cache do modelo
      everaldo/whisper-ffmpeg-cuda:<tag> \
      meu_audio.mp3 <opções_whisper>
    ```

    *   `--rm`: Remove o container após a execução.
    *   `--gpus all`: Habilita a GPU.
    *   `-v "$(pwd):/app"`: Monta o diretório atual do host em `/app` (o `WORKDIR` do container). O arquivo de entrada (`meu_audio.mp3`) deve estar aqui, e os resultados serão salvos aqui.
    *   `-v "$HOME/.cache/whisper:/root/.cache/whisper"`: Monta o diretório de cache do Whisper do host (`~/.cache/whisper` no Linux/macOS/WSL - pode variar no Windows) no local esperado pelo Whisper dentro do container. Isso **persiste os modelos baixados** entre as execuções. O modelo será baixado apenas na **primeira execução** que o necessitar.
    *   `everaldo/whisper-ffmpeg-cuda:<tag>`: Sua imagem no Docker Hub.
    *   `meu_audio.mp3 <opções_whisper>`: Argumentos passados para o comando `whisper` (arquivo de entrada e outras flags como `--model`, `--language`, `--output_format`, etc.).

    **Exemplo Específico (usando o modelo `medium` em português):**
    ```bash
    docker run \
      --rm \
      --gpus all \
      -v "$(pwd):/app" \
      -v "$HOME/.cache/whisper:/root/.cache/whisper" \
      everaldo/whisper-ffmpeg-cuda:12.8.1 \
      meu_video.mp4 --model medium --language Portuguese --output_format vtt
    ```

## Sobre OpenAI Whisper e Modelos

O Whisper é um modelo de redes neurais treinado em um grande dataset de áudio supervisionado. Ele pode transcrever áudio de diversos idiomas e também traduzir esses idiomas para o inglês.

Ele vem em diferentes tamanhos, variando em velocidade, precisão e requisitos de memória VRAM da GPU:

| Modelo         | Parâmetros | Tamanho Download | Memória VRAM (Estimativa) |
| :------------- | :--------- | :--------------- | :------------------------ |
| `tiny.en`      | 39M        | 75 MB            | ~1 GB                     |
| `tiny`         | 39M        | 75 MB            | ~1 GB                     |
| `base.en`      | 74M        | 140 MB           | ~1 GB                     |
| `base`         | 74M        | 140 MB           | ~1 GB                     |
| `small.en`     | 244M       | 460 MB           | ~2 GB                     |
| `small`        | 244M       | 460 MB           | ~2 GB                     |
| `medium.en`    | 769M       | 1.5 GB           | ~5 GB                     |
| `medium`       | 769M       | 1.5 GB           | ~5 GB                     |
| `large-v1`     | 1550M      | 2.9 GB           | ~10 GB                    |
| `large-v2`     | 1550M      | 2.9 GB           | ~10 GB                    |
| `large-v3`     | 1550M      | 2.9 GB           | ~10 GB                    |
| `large`        | Alias para a versão mais recente (`large-v3`) | 2.9 GB | ~10 GB |

**Notas:**
*   Os modelos `.en` são otimizados apenas para entrada em inglês e são um pouco mais rápidos.
*   Os modelos sem `.en` suportam todos os idiomas, incluindo detecção automática do idioma.
*   Os requisitos de VRAM são estimativas e podem variar dependendo da sua configuração e da versão específica do PyTorch/CUDA/driver. Modelos maiores exigem GPUs com mais VRAM.
*   O modelo `large` pode necessitar de GPUs com mais de 8GB de VRAM. Para GPUs com menos VRAM, modelos menores como `medium` ou `small` são mais adequados, ou a execução na CPU (muito mais lenta).

## Cache de Modelo Persistente via Volume

Como demonstrado no comando `docker run`, é crucial montar um volume para o diretório de cache do Whisper (`-v "$HOME/.cache/whisper:/root/.cache/whisper"`).

Na **primeira vez** que você executa um comando `whisper --model <nome_do_modelo>` com este volume montado, o modelo será baixado do site da OpenAI para o diretório de cache **no seu Host**.

Nas execuções subsequentes (mesmo em novos containers com `--rm`), o Whisper verificará o diretório de cache (agora populado via volume montado), encontrará o modelo e o carregará diretamente do seu Host, sem precisar baixá-lo novamente. Isso economiza tempo e banda significativamente.

## Flexibilidade com Argumentos de Build (Build Args)

O Dockerfile foi projetado para ser flexível usando os argumentos de build `NVIDIA_CUDA_BASE_TAG` e `PYTORCH_CUDA_SUFFIX`. Isso permite que você construa a imagem com a versão específica de CUDA e PyTorch que seja compatível com o driver NVIDIA instalado no seu sistema Host.

**Certifique-se sempre de que a versão CUDA da imagem base (`NVIDIA_CUDA_BASE_TAG`) e o sufixo do PyTorch (`PYTORCH_CUDA_SUFFIX`) correspondem à versão CUDA suportada pelo seu driver Host (verificada com `nvidia-smi`).**

Se tiver problemas com a versão do driver, você precisará:
1.  Atualizar o driver NVIDIA no seu Host, OU
2.  Construir a imagem usando `--build-arg`s que especifiquem uma base CUDA e PyTorch mais antigas e compatíveis com seu driver atual.
