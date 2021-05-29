FILE := NAME
OUT := build
NAME := 'NAME'
BUILD_OPTIONS := '-interaction=nonstopmode -pdf -halt-on-error'
MAKE_CMD := latexmk

.PHONY: pdf
pdf:
	$(MAKE_CMD) $(BUILD_OPTIONS) -outdir=$(OUT) $(FILE).tex;
	mv $(OUT)/$(FILE).pdf $(OUT)/$(NAME).pdf;

.PHONY: watch
watch:
	$(MAKE_CMD) $(BUILD_OPTIONS) -outdir=$(OUT) -pvc $(FILE).tex;

.PHONY: clean
clean:
	rm -rf $(filter-out $(OUT)/$(FILE).pdf, $(wildcard $(OUT)/*))

.PHONY: purge
purge:
	rm -rf $(OUT)
