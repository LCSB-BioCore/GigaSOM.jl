
# if (!requireNamespace("BiocManager", quietly = TRUE))
#   install.packages("BiocManager")
# BiocManager::install("flowCore")

library(flowCore)
library(readxl)
library(dplyr)

# install.packages('xlsx')
library(xlsx)

setwd("~/work/artificial_data_cytof")

conditions <- c("control", "venom", "p")

## create empty DF
md <- data.frame(file_name=character(),
                 sample_id=character(), 
                 condition=character(), 
                 stringsAsFactors=FALSE) 

#######################################
# 4 main cell lines, 6 marker per cell
colarray <- c(1:30)
nrowMatrix <- 100000
for (z in c(1:4)) {
  ## create XX vectors and bind to matirx
  ## random select z columns to be a cell line 
  ## with higher expr values multiply with 10 for testing
  # set.seed(1)
  A <- matrix(nrow = nrowMatrix, ncol = 33)
  for (i in colarray) {
    A[,i] <- runif(nrowMatrix, 0, 1)
    
  }
  
  cell_lines <- c(1:4)
  for (j in cell_lines) {
    selected <- sample(colarray,6)
    A[, selected] <- A[, selected] * runif(1, 10, 20)
  }
  
  L_marker <- read.csv("L_markers.csv", sep = ';')
  lineage_marker <- as.character(L_marker$Antigen)
  
  colnames(A) <- lineage_marker
  print(colnames(A))
  
  ## create a flowframe
  myNewFlowFrame <- new("flowFrame", exprs = A)
  
  filename <- paste0("file",z,".fcs")
  
  write.FCS(myNewFlowFrame, filename)

  new_row <- data.frame(file_name=as.character(filename), sample_id=as.character(z), condition=sample(conditions, 1))
  md <- rbind(md, new_row)
  
}

write.xlsx(md, "metadata.xlsx")
