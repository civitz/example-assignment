PANDOC=pandoc

INPUT=$(wildcard *.md)
PDFS=$(INPUT:.md=.pdf)

%.pdf: %.md
	$(PANDOC) -f markdown -o $@ $<

pdf: $(PDFS)

clean:
	rm *.pdf