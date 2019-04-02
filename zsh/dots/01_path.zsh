# Paths
# ------------------------------------------------------------------------------

# ruby
path=("/usr/local/lib/ruby/gems/2.6.0/bin" $path)

# homebrew
path=("/usr/local/bin:/usr/local/sbin" $path)

# python
path=("/usr/local/opt/python/libexec/bin" $path)

# nodejs 10 LTS
path=("/usr/local/opt/node@10/bin" $path)

# for compilers to find openssl
path=("/usr/local/opt/openssl/bin" $path)
export LDFLAGS="-L/usr/local/opt/openssl/lib"
export CPPFLAGS="-I/usr/local/opt/openssl/include"

# llvm
path=("/usr/local/opt/llvm/bin" $path)
export LDFLAGS="-L/usr/local/opt/llvm/lib"
export CPPFLAGS="-I/usr/local/opt/llvm/include"

# go
path=("${GOPATH}/bin:${GOROOT}/bin" $path)
