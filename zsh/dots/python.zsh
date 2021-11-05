if [[ $commands[ipython] ]]; then
  alias ipy='ipython'
  alias ippdb='ipython --pprint --pdb'
fi
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
  conda create --name $ENV_NAME python=3.7 neovim ipdb unidecode --yes;
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
