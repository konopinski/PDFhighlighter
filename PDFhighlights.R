pak::pak(c("reticulate","httr2"))
library(httr2)
library(reticulate)

if (!py_available(initialize = TRUE)) {
  reticulate::install_python()
  .rs.restartR()
}

py_require("pandas")
py_require("pymupdf")



# a function to combine keywords into regex search terms
make_regex <- function(word) {
  # A word boundary is required wherever the keyword is NOT wildcarded, so a
  # plain keyword such as "DNA" matches the standalone word only and never the
  # "dna" inside a word like "jednak". A leading or trailing '*' drops the
  # boundary on that side, preserving prefix / suffix / contains matching.
  left  <- if (startsWith(word, "*")) "" else "\\b"
  right <- if (endsWith(word, "*"))   "" else "\\b"
  
  # Escape regex metacharacters (the wildcard '*' is handled separately below)
  pattern <- gsub("([\\+\\.\\(\\)\\[\\]\\{\\}\\^\\$\\!\\?\\|])", "\\\\\\1", word)
  
  # '*' -> any run of characters that are not a separator or whitespace
  pattern <- gsub("\\*", "[^.\\\\s,?;:!]*", pattern)
  
  # a literal space between words -> one or more whitespace characters
  pattern <- gsub(" ", "\\\\s+", pattern)
  
  paste0(left, pattern, right)
}

make_regex_lines <- function(word) {
  pattern <- gsub("([\\+\\.\\(\\)\\[\\]\\{\\}\\^\\$\\!])", "\\\\\\1", word)
  pattern <- gsub("\\*", "[^. ,?;:!]*", pattern)
  pattern <- gsub(" ", " ", pattern)
  return(pattern)
}

# Example PDF - Polish Nature Protection Law
pdf_url <- "https://isap.sejm.gov.pl/isap.nsf/download.xsp/WDU20120001512/U/D20121512Lj.pdf"

# Fetching the document
resp <- request(pdf_url) |>
  req_user_agent("Mozilla/5.0 (R script for legal research)") |>
  req_perform()

# Saving the PDF
writeBin(resp_body_raw(resp), "ustawa_o_nasiennictwie.pdf")

#############################################
## Highlighting keywords in a PDF file ######
#############################################

Polish_keywords <- c("genom*", "gen", "geny", "genów", "genami", "*inbre*", "hybryd*", "*różnorodn*", 
                     "różnorodność biologiczna","ekosystem","habitat","biotop", "siedlisk*","gatun",
                     "genet*", "zmienn*", "zasob*", "adaptac*", "przystosowan*",	"odpornoś*", 
                     "wytrzmałoś*","wewnątrzgatunkow*",	"pul* genow*",  "chów", "wsobn*", "*kojarz*",
                     "adapt*","przystos*", "wymian", "pul", "sekwencj*", "DNA", "zuboż", "populac*",
                     "ras*", "wymiera*", "wymar*", "zamiera*", "wygin*", "endemi*", "inwentarz",
                     "zasoby", "pogłowie",	"stad*", "łącznoś*","wędr*", "*fragment*", "korytarz*",
                     "migr*", "izol*", "Cel* 4", "krio*")

##########################

regex_patterns <- as.list(unname(as.character(sapply(Polish_keywords, make_regex))))

# Pass variables to Python input
folder <- ("c:/Users/konopinski/Mój dysk (mkonop@wp.pl)/GENOA WG1 O1.1/")
files <- list.files(folder, pattern = ".pdf")
getwd()

for (file in  files){
  input_pdf <- paste0(folder, file)
  
  py$patterns <- regex_patterns
  py$input_pdf <- input_pdf 
  py$output_pdf <- paste0(folder,file,"_highlight.pdf")
  
  # Python script to run
  py_run_string("
import fitz
import re

doc = fitz.open(input_pdf)

if isinstance(patterns, str):
    patterns = [patterns]

combined_pattern = '|'.join(patterns)
combined_re = re.compile(combined_pattern, re.IGNORECASE)

for page in doc:
    # words: list of tuples (x0, y0, x1, y1, 'text', block_no, line_no, word_no)
    words = page.get_text('words')
    if not words:
        continue

    # Rebuild the page text in reading order and remember the character span
    # each word occupies. Words are joined with a single space so that the
    # whitespace token in a pattern matches the gap between two words whether
    # they were originally separated by a space, a tab or a line break.
    page_text = ''
    spans = []                       # (char_start, char_end, word_index)
    for i, w in enumerate(words):
        if i > 0:
            page_text += ' '
        start = len(page_text)
        page_text += w[4]
        spans.append((start, len(page_text), i))

    # Find every match across the whole page text, then collect each word the
    # match covers. This lets multi-word keywords (e.g. 'roznorodnosc
    # biologiczna') and multi-token wildcard keywords (e.g. 'pul* genow*',
    # 'Cel* 4') match even when broken across lines or padded with spaces/tabs.
    to_highlight = set()
    for m in combined_re.finditer(page_text):
        if m.start() == m.end():
            continue                 # ignore empty matches
        for start, end, idx in spans:
            if start < m.end() and end > m.start():   # word overlaps the match
                to_highlight.add(idx)

    # Highlight each matched word exactly once.
    for idx in to_highlight:
        rect = fitz.Rect(words[idx][:4])
        annot = page.add_highlight_annot(rect)
        annot.set_colors(stroke=[1, 1, 0])           # Yellow
        annot.update()

doc.save(output_pdf, garbage=4, deflate=True, clean=True)
doc.close()
")
}
