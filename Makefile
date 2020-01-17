PANDOC=pandoc
PLANT=plantuml

PUMLS=$(wildcard */*.puml)
DIAGS=$(PUMLS:.puml=.png)
MDS=$(wildcard exercise*.md)
PDFS=$(MDS:.md=.pdf)
DIST=assignment.tar.gz

%.png: %.puml
	$(PLANT) $<

%.pdf: %.md $(DIAGS)
	$(PANDOC) -f markdown -o $@ $< -V geometry:margin=2cm

pdf: $(PDFS) $(DIAGS)

dist: $(PDFS) $(DIAGS)
	rm -f $(DIST)
	tar -czf $(DIST) *

.PHONY : clean
clean:
	rm $(PDFS)
	rm $(DIAGS)
	rm $(DIST)