# disable start/stop characters in shell editor
unsetopt FLOW_CONTROL

# Allow [ or ]
unsetopt NOMATCH

# Write to multiple descriptors
setopt MULTIOS

# prevent accidental C-d from exiting shell
setopt IGNORE_EOF

# Report status of background jobs immediately.
setopt NOTIFY

# Wait 10 seconds until executing `rm` with a star, e.g. `rm path/*`.
setopt RM_STAR_WAIT
