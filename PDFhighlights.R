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
  pattern <- gsub("([\\+\\.\\(\\)\\[\\]\\{\\}\\^\\$\\!])", "\\\\\\1", word)
  pattern <- gsub("\\*", "[^. ,?;:!]*", pattern)
  pattern <- gsub(" ", "\\\\s+", pattern)
  
  return(pattern)
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
                     "migr*", "izol*", "Cel* 4", "krio*","*pokrew*")

##########################

regex_patterns <- as.list(unname(as.character(sapply(Polish_keywords, make_regex))))

# Pass variables to Python input
input_pdf <- "ustawa_o_nasiennictwie.pdf"

py$patterns <- regex_patterns
py$input_pdf <- input_pdf 
py$output_pdf <- paste0(sub(".pdf","",input_pdf ),"_highlight.pdf")

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
    # words is a list of tuples: (x0, y0, x1, y1, 'text', block_no, line_no, word_no)
    words = page.get_text('words')
    
    for w in words:
        # Check if the 5th element (index 4) matches our keywords
        if combined_re.search(w[4]):
            # Use the first 4 elements for coordinates
            rect = fitz.Rect(w[:4])
            annot = page.add_highlight_annot(rect)
            annot.set_colors(stroke=[1, 1, 0]) # Yellow
            annot.update()

doc.save(output_pdf, garbage=4, deflate=True, clean=True)
doc.close()
")

#################################################################################
# This version highlights entire lines in the PDF
#################################################################################
# 
# regex_patterns_lines <- as.list(unname(as.character(sapply(Polish_keywords, make_regex_lines))))
# 
# # Pass expressions to Python input
# py$patterns <- regex_patterns_lines
# py$output_pdf <- paste0(sub(".pdf","",input_pdf ),"_highlight_lines.pdf")
# 
# 
# # Highlighting and PDF export
# py_run_string("
# import fitz
# import re
# 
# doc = fitz.open(input_pdf)
# combined_re = re.compile('|'.join(patterns), re.IGNORECASE)
# 
# for page in doc:
#     words = page.get_text('words') # (x0, y0, x1, y1, 'text', ...)
#     if not words: continue
# 
#     # Group words into lines based on their vertical position
#     lines = []
#     current_line = [words[0]]
#     for w in words[1:]:
#         # If the bottom coordinate (w[3]) is close to the previous word, it's the same line
#         if abs(w[3] - current_line[-1][3]) < 3:
#             current_line.append(w)
#         else:
#             lines.append(current_line)
#             current_line = [w]
#     lines.append(current_line)
# 
#     # Search each recomposed line
#     for line in lines:
#         line_text = ' '.join([w[4] for w in line])
#         match = combined_re.search(line_text)
#         
#         if match:
#             # Highlight the entire span of the match
#             # This identifies which words in the line are part of the match
#             for w in line:
#                 if combined_re.search(w[4]) or combined_re.search(line_text):
#                    # To be precise, we only highlight words that are inside the match string
#                    rect = fitz.Rect(w[:4])
#                    annot = page.add_highlight_annot(rect)
#                    annot.set_colors(stroke=[1, 1, 0])
#                    annot.update()
# 
# doc.save(output_pdf, garbage=4, deflate=True, clean=True)
# doc.close()
# ")
