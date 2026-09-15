ensure_whisper_model() {
  local model="$HOME/.cache/whisper/ggml-large-v3-turbo.bin"

  if [[ -f "$model" ]]; then
    print_verbose "Whisper model is available"
    return 0
  fi

  print_info "Downloading whisper large-v3-turbo model (~1.6GB)"
  mkdir -p "$(dirname "$model")"
  if curl -sSL -o "$model" https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin; then
    print_success "Whisper model downloaded"
  else
    print_warning "Failed to download whisper model"
    rm -f "$model"
  fi
}
