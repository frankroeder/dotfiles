if [[ $+commands[ipython] ]]; then
  alias ipy="ipython --pdb"
  alias ippdb="ipython --pprint --pdb"
fi

alias pipup='$(which python3) -m pip install --upgrade pip'
alias pipreq='$(which python3) -m pip install -r $PWD/requirements.txt -U'


if [[ $+commands[uv] ]]; then
	eval "$(uv generate-shell-completion zsh)"
	alias uvreq='uv add --requirements $PWD/requirements.txt -U'
	uvact(){
		if git rev-parse --git-dir > /dev/null 2>&1; then
			cd $(git rev-parse --show-toplevel)
		fi
		source .venv/bin/activate
		echo "Current python: $(which python)";
		echo "Version: $(.venv/bin/python --version)"
	}
	uvspace(){
		print "The memory consumption per environment:"
		du -hcs $HOME/Documents/python/*/.venv | sort -hr;
	}
fi

if [[ $+commands[conda] ]]; then
	conact() {
		if git rev-parse --git-dir > /dev/null 2>&1; then
		  cd $(git rev-parse --show-toplevel)
		fi
  	conda activate $(basename $PWD);
  	echo "Version: $($CONDA_PREFIX/bin/python --version)"
  	echo "Current python: $(which python)";
  	echo "Current pip: $(which pip)";
	}
	conactz() {
  	conda activate $(conda env list | tail -n +3 | awk '{print $1}' | fzf)
  	echo "Version: $($CONDA_PREFIX/bin/python --version)"
  	echo "Current python: $(which python)";
  	echo "Current pip: $(which pip)";
	}
	concreate() {
  	local PY_VERSION=$(python3 --version 2>&1 | cut -d ' ' -f 2 | cut -d '.' -f 1,2)
		if git rev-parse --git-dir > /dev/null 2>&1; then
		  cd $(git rev-parse --show-toplevel)
		fi
  	local ENV_NAME=$(basename $PWD);
  	conda create --name $ENV_NAME python=$PY_VERSION neovim ipdb unidecode --yes;
  	conda activate $ENV_NAME;
	}
	conreq() {
  	conda install --yes --file "$PWD/requirements.txt";
	}
	condev() {
 		conda install --yes neovim ipdb unidecode
	}
	rmcenv() {
		if git rev-parse --git-dir > /dev/null 2>&1; then
		  cd $(git rev-parse --show-toplevel)
		fi
  	conda remove --name $(basename $PWD) --all;
	}
	rmcenvz() {
  	ENV_NAME=$(conda env list | tail -n +3 | awk '{print $1}' | fzf)
  	echo $ENV_NAME
  	if [[ -n "$ENV_NAME" ]]; then
    	conda remove --name $ENV_NAME --all;
  	fi
	}
	cpip() {
  	command $CONDA_PREFIX/bin/pip "$@";
	}
	contfm1() {
  	if [[ $OSTYPE == "Darwin" && $ARCHITECTURE == "arm64" ]]; then
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
fi
