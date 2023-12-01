
# There should be only one main texi file for each rule.
MAIN_TEX_FILE = How-to-build-toolchain.texi
OTH_TEX_FILES = version.texi
PNG_FILES = $(wildcard *.png)

all : How-to-build-toolchain.pdf

How-to-build-toolchain.pdf : $(MAIN_TEX_FILE) $(OTH_TEX_FILES) $(PNG_FILES)
	texi2pdf $<

clean:
	rm -rf *.aux *.cp *.cps *.fn *.ky *.log *.pdf *.pg *.toc *.tp *.vr
