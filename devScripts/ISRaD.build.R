#' ISRaD.build builds the database and updates objects in R package
#'
#' Wrapper function that combines tools for rapid deployment of R package data objects.
#' Meant to be used by the maintainers/developers of ISRaD
#'
#' @param ISRaD_directory directory where the ISRaD package is found
#' @param geodata_directory directory where geospatial datasets are found. Necessary to create ISRaD_Extra
#' @param geodata_keys directory where geospatial factor keys are found. Necessary to create ISRaD_Extra
#' @param citations T or F. Update citations.
#' @return runs QAQC on all datafiles, moves files that fail QAQC, updates ISRaD_Data, updates ISRaD_Extra
#' @import stringr
#' @export

ISRaD.build<-function(ISRaD_directory, geodata_directory, geodata_keys, citations=T){

  requireNamespace("stringr")
  requireNamespace("tidyverse")

# Compile database --------------------------------------------------------

  if (is.null(geodata_directory) | is.null(geodata_keys)){
    warning("geodata_directory, and geodata_keys directory must be specified.\n")
    stop()
  }


  message("Compiling the data files in ",  paste0(ISRaD_directory,"/ISRaD_data_files\n"))
  message("You must review the compilation report log file when complete (ISRaD_data_files/database/ISRad_log.txt)... \n\n")
  ISRaD_data_compiled<-compile(dataset_directory = paste0(ISRaD_directory,"/ISRaD_data_files/"), write_report = T, write_out = T, return_type = "list", checkdoi = F)

  message("\nISRaD_data.xlsx saved to ", paste0(ISRaD_directory,"/ISRaD_data_files/database\n\n"))

  reviewed<-utils::menu(c("Yes", "No"), title="Have you reviewed the compilation report log file? (ISRaD_data_files/database/ISRaD_log.txt). I would suggest using the git commit preview window in R to see changes.")
  if (reviewed==2){
    stop("You cannot build the ISRaD database without reviewing the compilation report log file...")
  }

  reviewed<-utils::menu(c("Yes", "No"), title="Did everything in the log file look ok?")
  if (reviewed==2){
    stop("You cannot build the ISRaD database if the log file shows problems...")
  }

# Replace data objects ----------------------------------------------------

  message("\nReplacing the ISRaD_data object with the new one...\n")

  message("\tChecking the number of new rows in the compiled ISRaD_data object...\n")
  load(paste0(ISRaD_directory, "/ISRaD_data_files/database/ISRaD_data.rda"))
  ISRaD_data<-ISRaD_data
  for(t in names(ISRaD_data_compiled)){
    message("\t\t", nrow(ISRaD_data_compiled[[t]])-nrow(ISRaD_data[[t]]), " rows were added to the ", t, " table.\n")
  }

  new_entries<-setdiff(ISRaD_data_compiled$metadata$entry_name,ISRaD_data$metadata$entry_name)
  if(length(new_entries)==0) new_entries <- "none"
  message("\t\t New entry_name values added to the data: ", new_entries, "\n")

  removed_entries<-setdiff(ISRaD_data$metadata$entry_name, ISRaD_data_compiled$metadata$entry_name)
  if(length(removed_entries)==0) removed_entries <- "none"
  message("\t\t entry_name values removed from the data: ", removed_entries, "\n")

  reviewed<-utils::menu(c("Yes", "No"), title="Are these differences what you expected?")
  if (reviewed==2){
  stop("You cannot replace the ISRaD_data object with a faulty data object...")
  }

  message("\nCreating the ISRaD_extra object...\n")
  message("\t filling dates \n")
  ISRaD_extra_compiled<-ISRaD.extra.fill_dates(ISRaD_data_compiled)
  message("\t filling 14c \n")
  ISRaD_extra_compiled<-ISRaD.extra.fill_14c(ISRaD_extra_compiled)
  message("\t filling fm \n")
  ISRaD_extra_compiled<-ISRaD.extra.fill_fm(ISRaD_extra_compiled)
  message("\t filling coordinates \n")
  ISRaD_extra_compiled<-ISRaD.extra.fill_coords(ISRaD_extra_compiled)
  message("\t filling delta delta \n")
  ISRaD_extra_compiled<-ISRaD.extra.delta_delta(ISRaD_extra_compiled)
  message("\t filling cstocks \n")
  ISRaD_extra_compiled<-ISRaD.extra.Cstocks(ISRaD_extra_compiled)
  message("\t filling expert data \n")
  ISRaD_extra_compiled<-ISRaD.extra.fill_expert(ISRaD_extra_compiled)
  message("\t filling geospatial data \n")
  ISRaD_extra_compiled<-ISRaD.extra.geospatial(ISRaD_extra_compiled, geodata_directory=geodata_directory)
  message("\t recoding categorical spatial data  \n")
  ISRaD_extra_compiled<-ISRaD.extra.geospatial.keys(ISRaD_extra_compiled, geodata_keys=geodata_keys)

  message("Replacing the ISRaD_extra object with the new one...\n")

  message("\tChecking the number of new columns in the compiled ISRaD_extra object...\n")
  load(paste0(ISRaD_directory, "/ISRaD_data_files/database/ISRaD_extra.rda"))
  ISRaD_extra<-ISRaD_extra
  for(t in names(ISRaD_extra_compiled)){
    message("\t\t", ncol(ISRaD_extra_compiled[[t]])-ncol(ISRaD_extra[[t]]), " ncol were added to the ", t, " table.\n")
  }

  reviewed<-utils::menu(c("Yes", "No"), title="Are these differences what you expected?")
  if (reviewed==2){
    stop("You cannot replace the ISRaD_data object with a faulty data object...")
  }

  # tag data w/ version number and date
  DESC<-readLines(paste0(ISRaD_directory, "/Rpkg", "/DESCRIPTION"))
  version<-unlist(strsplit(DESC[3],split = "\\."))
  version<-unlist(strsplit(version,split = "\\ "))
  version[4]<-as.numeric(version[4])+1 # updates patch version # (third column), use for codebase changes
  if(length(new_entries)!=0) {
    version[3]<-as.numeric(version[3])+1 # updates minor version # (second column), use for data changes (new templates)
  }
  v<-paste0("v",
           do.call(paste0, lapply(version[2:4], function(x) paste0(x, "."))),
           as.character(Sys.Date()))

  ISRaD_data<-ISRaD_data_compiled
  attributes(ISRaD_data)$version<-v
  save(ISRaD_data, file=paste0(ISRaD_directory, "/ISRaD_data_files/database/ISRaD_data.rda"))
  message("ISRaD_data has been updated...\n\n")

  ISRaD_extra<-ISRaD_extra_compiled
  attributes(ISRaD_extra)$version<-v
  save(ISRaD_extra, file=paste0(ISRaD_directory, "/ISRaD_data_files/database/ISRaD_extra.rda"))
  message("ISRaD_extra has been updated...\n\n")


# Save ISRaD extra object as Excel file --------------------------------------------------

  message("Replacing data files in /ISRaD_data_files/database/ISRaD_database_files/ ... new version number is ", v,"\n\n")

  ISRaD_extra_char<-lapply(ISRaD_extra, function(x) x %>% dplyr::mutate_all(as.character))
  openxlsx::write.xlsx(ISRaD_extra_char, file = file.path(ISRaD_directory, "ISRaD_data_files/database", "ISRaD_extra_list.xlsx"))

  system(paste0("rm ", paste0(ISRaD_directory, "/ISRaD_data_files/database/ISRaD_database_files/ISRaD*")))
  openxlsx::write.xlsx(ISRaD_extra_char, file = paste0(ISRaD_directory, "/ISRaD_data_files/database/ISRaD_database_files/", "ISRaD_extra_list_",v,".xlsx"))
  openxlsx::write.xlsx(ISRaD_data, file = paste0(ISRaD_directory, "/ISRaD_data_files/database/ISRaD_database_files/", "ISRaD_data_list_",v,".xlsx"))
  save(ISRaD_data, file=paste0(ISRaD_directory, "/ISRaD_data_files/database/ISRaD_database_files/ISRaD_data_",v,".rda"))
  save(ISRaD_extra, file=paste0(ISRaD_directory, "/ISRaD_data_files/database/ISRaD_database_files/ISRaD_extra_",v,".rda"))

# Flattened data objects --------------------------------------------------

  message("\tUpdating flattened data objects...\n")
  for(tab in c("flux","layer","interstitial","incubation","fraction")){
    flattened_data<-ISRaD.flatten(database=ISRaD_data, table = tab)
    #flattened_data<-str_replace_all(flattened_data, "[\r\n]" , "")
    message("writing ISRaD_data_flat_", tab, ".csv"," ...\n", sep = "")
    utils::write.csv(flattened_data, paste0(ISRaD_directory,"/ISRaD_data_files/database/", "ISRaD_data_flat_", tab, ".csv"))
    utils::write.csv(flattened_data, paste0(ISRaD_directory,"/ISRaD_data_files/database/ISRaD_database_files/", "ISRaD_data_flat_", tab,"_",v, ".csv"))

    flattened_extra<-ISRaD.flatten(database=ISRaD_extra, table = tab)
    #flattened_extra<-str_replace_all(flattened_extra, "[\r\n]" , "")
    message("writing ISRaD_extra_flat_", tab, ".csv"," ...\n", sep = "")
    utils::write.csv(flattened_extra, paste0(ISRaD_directory,"/ISRaD_data_files/database/", "ISRaD_extra_flat_", tab, ".csv"))
    utils::write.csv(flattened_extra, paste0(ISRaD_directory,"/ISRaD_data_files/database/ISRaD_database_files/", "ISRaD_extra_flat_", tab,"_",v, ".csv"))

  }
  system(paste0("rm ", paste0(ISRaD_directory, "/ISRaD_data_files/database/ISRaD_database_files.zip")))

  setwd(paste0(ISRaD_directory,"/ISRaD_data_files/database/ISRaD_database_files"))
  utils::zip(zipfile = paste0("../ISRaD_database_files"), files = list.files(paste0(ISRaD_directory,"/ISRaD_data_files/database/ISRaD_database_files"), full.names = F))
  setwd(ISRaD_directory)

# update references -------------------------------------------------------

  if(removed_entries != "none" | new_entries !="none") {
  message("\nUpdating credits.md page...this takes about 5 min")

  dois=as.character(ISRaD_data$metadata$doi)
  cleandois=dois[dois[]!="israd"]

  he_doi="10.1126/science.aad4273"
  mathieu_doi="10.1111/gcb.13012"

  # References from clean dois
  a=sapply(cleandois,FUN=rcrossref::cr_cn, format="text", style="apa", USE.NAMES = FALSE)

  he_ref=rcrossref::cr_cn(he_doi,format="text", style="apa")
  mathieu_ref=rcrossref::cr_cn(mathieu_doi,format="text", style="apa")

  # Body
  h1="## Main compilations"
  p1="ISRaD has been built based on two main compilations:"

  h2="## Studies within ISRaD"
  n=length(cleandois)
  p2=paste("Currently, there are", n, "entries in ISRaD, which are from the following publications:")

  # Print markdown file for website
  message(c(h1, p1, " ", paste("* ",mathieu_ref), paste("* ",he_ref), " ",
        h2, p2, " ", paste("* ",a)), sep="\n", file="ISRaD_data_files/database/credits.md")

  }

# document and check ------------------------------------------------------

  message("\tUpdating documentation and running check()...\n")

  devtools::document(pkg = paste0(ISRaD_directory,"/Rpkg"))
  devtools::check(pkg=paste0(ISRaD_directory,"/Rpkg"), manual = T, cran = T, run_dont_test = T)

  errors<-1
  while(errors==1){
  errors<-utils::menu(c("Yes", "No"), title="Were there any errors, warnings, or notes?")
  if (errors==1){
    message("Ok, please fix the issues and confim below when you are ready to run the check again...\n")
    ready<-utils::menu(c("Yes", "No"), title="Are you ready to run the check again?")
    if (ready==1){
      devtools::check(pkg=paste0(ISRaD_directory,"/Rpkg"), manual = T, cran = T, run_dont_test = T)
   }
  }
  }


  system(paste0("rm ", paste0(ISRaD_directory, "/Rpkg"), "/ISRaD.pdf"))
  devtools::build_manual(paste0(getwd(),"/Rpkg"), paste0(getwd(),"/Rpkg"))

  reviewed<-utils::menu(c("Yes", "No"), title="Are you going to push this to github?")
  if (reviewed==1){
    message("Ok, the DESCRIPTION file is being updated with a new version...\n")
    if(length(new_entries)!=0) {
      message(paste(length(new_entries), " new entries have been added, so the minor version number will be updated"))
    }
    DESC[3]<-paste(unlist(version), collapse = ".")
    writeLines(DESC, paste0(ISRaD_directory, "/Rpkg", "/DESCRIPTION"))
    message("Ok, you can now commit and push this to github!\n You should also then reload R and reinstall ISRaD from github.\n")
  }

}
