

# library(httr2)
# library(dplyr)
# library(purrr)



##############################################################################
##############################################################################
###### this section was ment to download documents via API ###################
###### the problem is that only a few countries implemeted ELI system ########
###### it could be however used in the future searches #######################
###### this code was created to import Polish gazettes #######################
##############################################################################
##############################################################################
# 
# publisher <- "DU"
# year <- 1964
# api_url <- paste("https://sejm.gov.pl", publisher, year, sep = "/")
# 
# resp <- request(api_url) |>
#   req_method("GET") |>
#   req_headers(Accept = "application/json") |>
#   req_retry(max_tries = 3) |>
#   req_perform()
# 
# if (resp_content_type(resp) == "application/json") {
#   raw_data <- resp_body_json(resp)
#   
#   acts_metadata <- map_df(raw_data$items, ~as_tibble(t(unlist(.x))))
#   print(head(acts_metadata))
# } 
#
##############################################################################
##############################################################################
########## marking keywords in PDF documents #################################
##############################################################################
##############################################################################

# install python handler

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

# full list of keywords
# keywords <- c("bioróżnorodn*", "różnorodno* biologiczn*",	"ekosystem*", "habitat*", "siedlisk*",
#               "*gatun*",	"genet*", "*adapt*", "przystosowan*",	"odporno*", "wytrzmał*", "genow*",
#               "gen", "geny","genów","genami", 	"wsobn*", "przystos*",	"genowej",	"sekwencj", 
#               "*DNA", "*populac*", "wymieran*", "zamieran*",	"endemi*",	"inwentarz*", "zasob*", 
#               "pogłowi*",	"stad*",	"łącznoś*",	"fragmentac*",	"korytarz*", "*izolac*", "*izolow",	
#               "cel* 4",	"krio*")



Polish_keywords <- c("genet*", "genom*", "*adapt*", "przystosowan*", "odporno*", "wytrzmał*", "genow*",
              "gen", "geny", "genów", "genami", "wsobn*", "przystos*", "genowej", "sekwencj*", 
              "*DNA", "*populac*", "wymieran*", "zamieran*", "endemi*", "inwentarz*", "zasob*", 
              "pogłowi*", "stad*", "łącznoś*", "fragmentac*", "korytarz*", "*izolac*", "*izolow*",
              "Wędrów*", +"cel* 4", "krio*", "*różnorod*", )


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
# 
# ####################################################
# ########### GERMAN #################################
# ####################################################
# 
# 
# 
# German_kw <- c("Biodiversität", "Ökosystem", "Habitat", "Lebensraum", "Lebensstätte", "Art",
# "Arten", "Genetische Diversität", "Genetische Ressourcen", "Adaptation", "Anpassung",
# "Widerstandsfähigkeit", "Belastbarkeit", "Widerstandskraft", "innerartliche Diversität",
# "innerartliche Vielfalt", "Genkonservierung", "zwischenartliche Diversität", "genet*",
# "Inzucht", "inzüchtig", "ererbt", "ingezüchtet", "adapt*", "an*pass*",
# "adaptives Potential", "Potenzial", "genet* Level", "Level", "genetischer Austausch",
# "Austausch zwischen Populationen", "digitale Sequenzinformation*", "Sequenzinformation*",
# "Gentechnik", "gentechnisch", "Gentechnikgesetz", "genetische Auszehrung", "Minderung",
# "Ausdünnung", "Erschöpfung", "genetische Angelegenheit", "Rückgang", "Verfall", "Minderung",
# "Verschlechterung genetische Diversität", "Genbank", "genetische[s] Information", "Wissen",
# "effektive Populationsgröße", "Zucht", "züchtet", "züchten", "Züchter", "kleine Population",
# "große Population", "Aussterben", "Ausrottung", "Vernicht*", "einheimisch", "angesiedelt",
# "vorherrschend", "heimisch", "standortheimisch", "Population", "Populationen", "Bestand",
# "Herkunft", "Herkünfte", "Herde", "Rudel", "Verbindung", "Vernetzung", "Vernetzungsfunktion",
# "Fragmentierung", "Zerteilung", "Zersplitterung", "Korridor", "Schneise", "Gang",
# "genetische Variation", "Isol*", "Genpool", "Genvorrat", "genetisch divers", "Target 4",
# "Ziel 4", "kryo*")
# 
# 
# ##########################
# 
# 
# regex_patterns <- as.list(unname(as.character(sapply(German_kw, make_regex))))
# 
# # Pass variables to Python input
# input_pdf <- "BNatSchG.pdf"
# py$patterns <- regex_patterns
# py$input_pdf <- input_pdf 
# py$output_pdf <- paste0(sub(".pdf","",input_pdf ),"_highlight.pdf")
# 
# # Python script to run
# py_run_string("
# import fitz
# import re
# 
# doc = fitz.open(input_pdf)
# 
# if isinstance(patterns, str):
#     patterns = [patterns]
# 
# combined_pattern = '|'.join(patterns)
# combined_re = re.compile(combined_pattern, re.IGNORECASE)
# 
# for page in doc:
#     # words is a list of tuples: (x0, y0, x1, y1, 'text', block_no, line_no, word_no)
#     words = page.get_text('words')
#     
#     for w in words:
#         # Check if the 5th element (index 4) matches our keywords
#         if combined_re.search(w[4]):
#             # Use the first 4 elements for coordinates
#             rect = fitz.Rect(w[:4])
#             annot = page.add_highlight_annot(rect)
#             annot.set_colors(stroke=[1, 1, 0]) # Yellow
#             annot.update()
# 
# doc.save(output_pdf, garbage=4, deflate=True, clean=True)
# doc.close()
# ")
# 
# #################################################################################
# # This version highlights entire lines in the PDF
# #################################################################################
# 
# make_regex_lines <- function(word) {
#   pattern <- gsub("([\\+\\.\\(\\)\\[\\]\\{\\}\\^\\$\\!])", "\\\\\\1", word)
#   pattern <- gsub("\\*", "[^. ,?;:!]*", pattern)
#   pattern <- gsub(" ", " ", pattern)
#   return(pattern)
# }
# 
# regex_patterns <- as.list(unname(as.character(sapply(German_kw, make_regex_lines))))
# py$output_pdf <- paste0(sub(".pdf","",input_pdf ),"_highlight_lines.pdf")
# py$patterns <- regex_patterns
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
# 
# 
# ######################################################################
# ######################################################################
# ######################################################################
# 
# 
# Eng_kw <- c("Resilience", "Within species diversit*", "Genet*", "Gene", "Genes", "Intraspecific diversit*", 
#                "inbre*", "*adapt*",  "Digital sequencing*", "effective size", "population size", "breed*", 
#                "extinct*", "endemi*", "*population*", "*stock", "herd*", "connectivit*", "fragment*", 
#                "corridor*", "migrat*", "isolat*", "Target 4", "cryo*")
# 
# 
# English_terms <- c("genet*","gene","genes","trait*","inbre*","breed*","restock*",
#                    "supplement*","reintroduct*","hybrid*","introgress*","evolution*",
#                    "heterozyg*","polymorp*","variet*","crop wild","wild crop",
#                    "crop relative*","landrace*","cultivar*","effective population",
#                    "effective size*","small* population*","large* population*",
#                    "population size*","Ne500","Ne 500","drift","bottleneck*",
#                    "Target 4","A.4","biotechnology","molecular","DNA*","fingerprinting"
#                    ,"GMO*","cryo*","genom*","sequenc*","connectivit*","fragmentation*",
#                    "fragmented","corridor*","isolat*","migrat*","migrant*","intra*",
#                    "genotyp*","allel*","fitness","local adaptation*","adaptive potential*",
#                    "pedigr*","captive breeding","ex-situ","in-situ","germplasm*","biobank*",
#                    "population structure*","subpopulation*","SNP*","microsatellite*",
#                    "transcriptom*","eDNA*","bioinformatic*","Target4","Target.4","4th Target",
#                    "A. 4","A4","population effective","within species diversity","land race*",
#                    "inter population","inter-population","interpopulation","homozyg*",
#                    "haplotyp*","nucleotid*","phenotype*","selective sweep*","selective adventage*",
#                    "founder event*","founder effect*","metapopulation*","panmi*",
#                    "phylogeograph*","high-throughput seq*")
# 
# 
# 
# regex_patterns <- as.list(unname(as.character(sapply(English_terms, make_regex))))
# 
# # Pass variables to Python input
# input_pdf <- "C:/Users/konopinski/Downloads/scbd-ort-nr7-za-287909-1.pdf"
# 
# 
# py$patterns <- regex_patterns
# py$input_pdf <- input_pdf 
# py$output_pdf <- paste0("South_Africa_",basename(sub(".pdf","",input_pdf )),"_highlight.pdf")
# 
# # Python script to run
# py_run_string("
# import fitz
# import re
# 
# doc = fitz.open(input_pdf)
# 
# if isinstance(patterns, str):
#     patterns = [patterns]
# 
# combined_pattern = '|'.join(patterns)
# combined_re = re.compile(combined_pattern, re.IGNORECASE)
# 
# for page in doc:
#     # words is a list of tuples: (x0, y0, x1, y1, 'text', block_no, line_no, word_no)
#     words = page.get_text('words')
#     
#     for w in words:
#         # Check if the 5th element (index 4) matches our keywords
#         if combined_re.search(w[4]):
#             # Use the first 4 elements for coordinates
#             rect = fitz.Rect(w[:4])
#             annot = page.add_highlight_annot(rect)
#             annot.set_colors(stroke=[1, 1, 0]) # Yellow
#             annot.update()
# 
# doc.save(output_pdf, garbage=4, deflate=True, clean=True)
# doc.close()
# ")
# 
# #################################################################################
# # This version highlights entire lines in the PDF
# #################################################################################
# 
# regex_patterns_lines <- as.list(unname(as.character(sapply(English_terms, make_regex_lines))))
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
# 
