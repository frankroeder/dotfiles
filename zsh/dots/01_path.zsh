# Paths
# ------------------------------------------------------------------------------

# ruby
export PATH="/usr/local/lib/ruby/gems/2.6.0/bin:$PATH"

# homebrew
export PATH="/usr/local/bin:/usr/local/sbin:$PATH"

# python
export PATH="/usr/local/opt/python/libexec/bin:$PATH"

# nodejs 10 LTS
export PATH="/usr/local/opt/node@10/bin:$PATH"

# for compilers to find openssl
export PATH="/usr/local/opt/openssl/bin:$PATH"
export LDFLAGS="-L/usr/local/opt/openssl/lib"
export CPPFLAGS="-I/usr/local/opt/openssl/include"

# llvm
export PATH="/usr/local/opt/llvm/bin:$PATH"
export LDFLAGS="-L/usr/local/opt/llvm/lib"
export CPPFLAGS="-I/usr/local/opt/llvm/include"

# go
export PATH="$PATH:${GOPATH}/bin:${GOROOT}/bin"

# custom bin
export PATH="$HOME/.dotfiles/bin:$PATH"
