#' ISRaD.extra
#'
#' @description Fills in transformed and geospatial data where possible, generating an enhanced version of ISRaD.
#' @param database soilcarbon dataset object
#' @param geodata_directory directory where geospatial data are found
#' @details Fills fraction modern, delta 14C, delta-delta values, profile coordinates, BD, orgC, and SOC stocks from entered data; fills soil and climatic data from external geospatial data products
#' @export
#' @return returns new ISRaD_extra object with derived, transformed, and filled columns
#' @examples
#' \donttest{
#' # Load example dataset Gaudinski_2001
#' database <- ISRaD::Gaudinski_2001
#' # Fill ISRaD.extra data
#' database.x <- ISRaD.extra(database,
#'  geodata_directory = system.file("extdata", "geodata_directory", package = "ISRaD"))
#' }

ISRaD.extra<-function(database, geodata_directory){

  message("\t filling dates \n")
  database<-ISRaD.extra.fill_dates(database)
  message("\t filling 14c \n")
  database<-ISRaD.extra.fill_14c(database)
  message("\t filling fm \n")
  database<-ISRaD.extra.fill_fm(database)
  message("\t filling coordinates \n")
  database<-ISRaD.extra.fill_coords(database)
  message("\t filling delta delta \n")
  database<-ISRaD.extra.delta_delta(database)
  message("\t filling cstocks \n")
  database<-ISRaD.extra.Cstocks(database)
  message("\t filling geospatial data \n")
  database<-ISRaD.extra.geospatial(database, geodata_directory=geodata_directory, fillWorldClim=TRUE)

  ISRaD_data_filled <- database

  return(ISRaD_data_filled)

}
