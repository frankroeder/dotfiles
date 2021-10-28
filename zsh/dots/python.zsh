if [[ $commands[ipython] ]]; then
  alias ipy='ipython'
  alias ippdb='ipython --pprint --pdb'
fi
alias pipup='$(which python3) -m pip install --upgrade pip'
alias pipreq='$(which python3) -m pip install -r $(PWD)/requirements.txt'

conact() {
  conda activate $(basename $(PWD));
  echo "Current python : $(which python)";
  echo "Current pip : $(which pip)";
}
concreate() {
  local ENV_NAME=$(basename $(PWD));
  conda create --name $ENV_NAME neovim ipdb unidecode -y;
  conda activate $ENV_NAME;
}
conreq() {
  conda install -y --file "$PWD/requirements.txt";
}
rmcenv() {
  conda remove -n $(basename $(PWD)) --all;
}
