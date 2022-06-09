ipy() {
  (( $+commands[ipython] )) && ipython || echo "ipython not found"
}
ippdb() {
  (( $+commands[ipython] )) && ipython --pprint --pdb || echo "ipython not found"
}

alias pipup='$(which python3) -m pip install --upgrade pip'
alias pipreq='$(which python3) -m pip install -r $PWD/requirements.txt -U'

conact() {
  conda activate $(basename $PWD);
  echo "Version: $($CONDA_PREFIX/bin/python --version)"
  echo "Current python: $(which python)";
  echo "Current pip: $(which pip)";
}
concreate() {
  local ENV_NAME=$(basename $PWD);
  conda create --name $ENV_NAME python=3 neovim ipdb unidecode --yes;
  conda activate $ENV_NAME;
}
conreq() {
  conda install --yes --file "$PWD/requirements.txt";
}
condev() {
 conda install --yes neovim ipdb unidecode
}
rmcenv() {
  conda env remove --name $(basename $PWD) --all;
}
cpip() {
  command $CONDA_PREFIX/bin/pip "$@";
}
contfm1() {
  if [[ $OSTYPE == "Darwin" && $ARCHITECURE == "arm64" ]]; then
    # https://developer.apple.com/metal/tensorflow-plugin/
    conda install -c apple tensorflow-deps;
    python3 -m pip install tensorflow-macos;
    python3 -m pip install tensorflow-metal;
  else
    echo "Failed";
  fi
}
conspace(){
  print "The memory consumption per environment:"
  du -hcs $(conda info --base)/envs/* | sort -hr;
}
conup() {
  conda update --all;
}
