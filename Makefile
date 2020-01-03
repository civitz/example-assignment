PANDOC=pandoc
PLANT=plantuml

PUMLS=$(wildcard */*.puml)
DIAGS=$(PUMLS:.puml=.png)
MDS=$(wildcard *.md)
PDFS=$(MDS:.md=.pdf)

%.png: %.puml
	$(PLANT) $<

%.pdf: %.md $(DIAGS)
	$(PANDOC) -f markdown -o $@ $<

pdf: $(PDFS) $(DIAGS)

clean:
	rm *.pdf