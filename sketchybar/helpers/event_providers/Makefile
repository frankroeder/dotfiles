all:
	(cd cpu_load && $(MAKE))
	(cd memory_load && $(MAKE))
	@if [ -d media_nowplaying ]; then (cd media_nowplaying && $(MAKE)); fi
	(cd network_load && $(MAKE))
