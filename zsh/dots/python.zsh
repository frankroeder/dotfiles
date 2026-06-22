if (( ${+commands[ipython]} )); then
  alias ipy="ipython --pdb"
  alias ippdb="ipython --pprint --pdb"
fi

if (( ${+commands[uv]} )); then
  eval "$(uv generate-shell-completion zsh)"
  # eval "$(uvx --generate-shell-completion zsh)"
  alias pipup='uv pip install --upgrade pip'
  alias pipreq='uv pip install -r "$PWD/requirements.txt" -U'
  alias uvreq='uv add --requirements "$PWD/requirements.txt" -U'
  uvact(){
    if git rev-parse --git-dir > /dev/null 2>&1; then
      cd "$(git rev-parse --show-toplevel)"
    fi
    source .venv/bin/activate
    echo "Current python: $(command -v python)"
    echo "Version: $(.venv/bin/python --version)"
  }
  uvspace(){
    print "The memory consumption per environment:"
    du -hcs "$HOME"/Documents/python/*/.venv | sort -hr
  }
  if (( ${+commands[ty]} )); then
    eval "$(ty generate-shell-completion zsh)"
  fi
fi

if (( ${+commands[conda]} )); then
  conact() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
      cd "$(git rev-parse --show-toplevel)"
    fi
    conda activate "$(basename "$PWD")"
    echo "Version: $("$CONDA_PREFIX/bin/python" --version)"
    echo "Current python: $(command -v python)"
    echo "Current pip: $(command -v pip)"
  }
  conactz() {
    conda activate "$(conda env list | awk 'NR > 2 {print $1}' | fzf)"
    echo "Version: $("$CONDA_PREFIX/bin/python" --version)"
    echo "Current python: $(command -v python)"
    echo "Current pip: $(command -v pip)"
  }
  concreate() {
    local PY_VERSION
    PY_VERSION=$(python --version 2>&1 | awk '{print $2}' | cut -d '.' -f 1,2)
    if git rev-parse --git-dir > /dev/null 2>&1; then
      cd "$(git rev-parse --show-toplevel)"
    fi
    local ENV_NAME
    ENV_NAME=$(basename "$PWD")
    conda create --name "$ENV_NAME" python="$PY_VERSION" neovim ipdb unidecode --yes
    conda activate "$ENV_NAME"
  }
  conreq() {
    conda install --yes --file "$PWD/requirements.txt"
  }
  condev() {
    conda install --yes neovim ipdb unidecode
  }
  rmcenv() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
      cd "$(git rev-parse --show-toplevel)"
    fi
    conda remove --name "$(basename "$PWD")" --all
  }
  rmcenvz() {
    ENV_NAME=$(conda env list | awk 'NR > 2 {print $1}' | fzf)
    echo "$ENV_NAME"
    if [[ -n "$ENV_NAME" ]]; then
      conda remove --name "$ENV_NAME" --all
    fi
  }
  cpip() {
    command "$CONDA_PREFIX/bin/pip" "$@"
  }
  contfm1() {
    if [[ $OSTYPE == "Darwin" && $ARCHITECTURE == "arm64" ]]; then
      # https://developer.apple.com/metal/tensorflow-plugin/
      conda install -c apple tensorflow-deps
      python -m pip install tensorflow-macos
      python -m pip install tensorflow-metal
    else
      echo "Failed"
    fi
  }
  conspace(){
    print "The memory consumption per environment:"
    du -hcs "$(conda info --base)"/envs/* | sort -hr
  }
  conup() {
    conda update --all
  }
fi

pyzen() {
  uv run python -c "import this"
}
