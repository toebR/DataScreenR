#shinyapp to summarise structure of Excel data: Data ScreenR
#by Tobias Stalder
#(c) 2022
#Creative Commons Licence
#
#

# libraries ---------------------------------------------------------------


options(scipen=999)
library(shiny)
library(shinythemes)
library(shinydashboard)
library(readxl)
library(tidyverse)
library(skimr)

# functions ---------------------------------------------------------------

dat_glimpse <- function(data) {
  
  data %>% summary.default %>% as.data.frame %>%
    dplyr::group_by(Var1) %>%  tidyr::spread(key = Var2, value = Freq) -> mode
  
  data%>%summary%>%as.data.frame()%>% tidyr::drop_na(Freq) -> math
  
  dplyr::left_join(mode, math, by = c("Var1" = "Var2")) -> all
  
  all %>%
    dplyr::select(-c(Var1.y)) %>%
    dplyr::mutate(Freq = ifelse(is.na(Freq), "UNKNOWN", Freq)) %>%
    dplyr::filter(!stringr::str_detect(Freq, 'Mode')) %>%
    dplyr::filter(!stringr::str_detect(Freq, 'Class')) %>%
    dplyr::filter(!stringr::str_detect(Freq, 'Median')) %>%
    dplyr::filter(!stringr::str_detect(Freq, '1st')) %>%
    dplyr::filter(!stringr::str_detect(Freq, '3rd'))-> all_out
  
  
  skimmed_reduced <- tibble::tibble(skimr::skim(data))
  skimmed_reduced %>%
    dplyr::select(skim_variable, n_missing) -> skim
  
  if ("character.n_unique" %in% base::colnames(skimmed_reduced)){
    char_cols <- skimmed_reduced %>%
      dplyr::select(skim_variable, character.n_unique) %>%
      dplyr::rename(char_unique_n = character.n_unique)
  } else {
    char_cols <- tibble::tibble(skim_variable = skimmed_reduced$skim_variable,
                                char_unique_n =c(base::rep(NA, base::nrow(skimmed_reduced))))
  }
  
  if ("logical.count" %in% base::colnames(skimmed_reduced)){
    log_cols <- skimmed_reduced %>%
      dplyr::select(skim_variable, logical.count) %>%
      dplyr::rename(logical_count = logical.count)
  } else {
    log_cols <- tibble::tibble(logical_count =c(base::rep(NA, base::nrow(skimmed_reduced))),
                               skim_variable = skimmed_reduced$skim_variable)
  }
  
  if ("numeric.p0" %in% base::colnames(skimmed_reduced)){
    num_cols <- skimmed_reduced %>%
      dplyr::select(skim_variable, numeric.p0, numeric.p100, numeric.mean) %>%
      dplyr::rename(num_min = numeric.p0,
                    num_max = numeric.p100,
                    num_mean = numeric.mean)
  } else {
    num_cols <- tibble::tibble(num_min =c(base::rep(NA, nrow(skimmed_reduced))),
                               num_max =c(base::rep(NA, base::nrow(skimmed_reduced))),
                               num_mean =c(base::rep(NA, base::nrow(skimmed_reduced))),
                               skim_variable = skimmed_reduced$skim_variable)
  }
  
  if ("POSIXct.min" %in% colnames(skimmed_reduced)){
    dat_cols <- skimmed_reduced %>%
      dplyr::select(skim_variable, POSIXct.min, POSIXct.max, POSIXct.n_unique) %>%
      dplyr::rename(date_min = POSIXct.min,
                    date_max = POSIXct.max,
                    date_unique_n = POSIXct.n_unique) %>%
      dplyr::mutate(date_min = base::as.character(date_min),
                    date_max = base::as.character(date_max))
  } else {
    dat_cols <- tibble::tibble(date_min =c(base::rep(NA, base::nrow(skimmed_reduced))),
                               date_max =c(base::rep(NA, base::nrow(skimmed_reduced))),
                               date_unique_n =c(base::rep(NA, base::nrow(skimmed_reduced))),
                               skim_variable = skimmed_reduced$skim_variable)
  }
  
  dplyr::left_join(skim, dplyr::left_join(char_cols, dplyr::left_join(num_cols, dplyr::left_join(log_cols, dat_cols)))) %>%
    dplyr::rename(attribute = skim_variable) -> skim_selection
  
  skim_selection
  
  # print(skim_selection)
  
  dplyr::left_join(all_out, skim_selection, by = c("Var1" = "attribute")) %>%
    dplyr::select(-c(Freq)) %>%
    dplyr::distinct() %>%
    dplyr::rename(attribute = Var1)-> result
  
  result
}

# UI
ui <- fluidPage(theme = shinytheme("slate"),

    # Application title
    titlePanel(title= "Data ScreenR v.1.0.3"),


    sidebarLayout(
      
      sidebarPanel(
        
        helpText("This Webapp..."),
        helpText("(1) ...summarises excel sheet data into datatypes and datamodes per header attribute."),
        helpText("(2) ...calculates missing data and descriptive parameters."),
        br(),
        fileInput("Datasheet",label ="Excel Input", accept = c(".xlsx")),
        
        
        br(),
        br(),
        h4("Data Input Structure:"),
        h5("*Only the first worksheet is analysed."),
        h5("*Excel files can only have one header row."),
        br(),
        br(),
        br(),
        br(),
        br(),
        br(),
        br(),
        br(),
        br(),
        br(),
        h5("(c) Tobias Stalder | 2022")

        
      ),
      mainPanel(
        textOutput("InPath"),
        tabsetPanel(type = "tabs",
                    tabPanel("Raw Data (6 rows)", tableOutput("table")),
                    tabPanel("Summary", tableOutput("table2")),
                    tabPanel("Documentation",
                             h3("General Information"),
                             h6("Maximum Upload Size: 50mb"),
                             h6("Accepted Filetypes: xls, xlsx"),
                             h6("Consider uploading excel files containting ONLY one worksheet"),
                             h3("Versioning"),
                             h6("v.1.0.1: Prototype with reduced functionality"),
                             h6("v.1.0.2: Extended flexible functionality with inputs including POSIXct format"),
                             h6("V.1.0.3: Bugfix for disappearing Attributes in Summary"),
                             h3("Contact for Help"),
                             h6("Tobias Stalder"),
                             h6("tobias.stalder.geo@outlook.com"),
                             br(),
                             h6("Source Code:"),
                            ),
                 ),

    )
    )
)

#max request size of excel input
options(shiny.maxRequestSize=50*1024^2) 
server <- function(input, output) {
  
  
  #input file
  output$InPath <- renderText({
    paste("Your Input Excel Sheet:", input$Datasheet[1])
  })
  

  

    output$table <- renderTable({
      
      req(input$Datasheet)
      
      inFile <- input$Datasheet
      
      data <- read_excel(inFile$datapath, 1, guess_max = 21474836)
      
      head(data)
      
      
      
    })
  
    
    output$table2 <- renderTable({
      req(input$Datasheet)
      
      inFile <- input$Datasheet
      
      data <- read_excel(inFile$datapath, 1, guess_max = 21474836)
      
      dat_glimpse(data) -> results
      results
    })
    
  }

# Run the application 
shinyApp(ui = ui, server = server)
