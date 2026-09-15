ensure_whisper_model() {
  local model="$HOME/.cache/whisper/ggml-small.bin"

  if [[ -f "$model" ]]; then
    print_verbose "Whisper model is available"
    return 0
  fi

  print_info "Downloading whisper small model (~500MB)"
  mkdir -p "$(dirname "$model")"
  if curl -sSL -o "$model" https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin; then
    print_success "Whisper model downloaded"
  else
    print_warning "Failed to download whisper model"
    rm -f "$model"
  fi
}
