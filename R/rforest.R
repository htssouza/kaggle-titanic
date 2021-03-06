################################################################################
# Kaggle Titanic Challenge
# https://www.kaggle.com/c/titanic
################################################################################

################################################################################
# Dependencies and Libraries
################################################################################

for (.requirement in c("data.table", "magrittr", "randomForest")) {
  if (! .requirement %in% rownames(installed.packages())) {
    install.packages(.requirement, repos="http://cran.rstudio.com/")
  }
}

library(data.table)
library(magrittr)
library(randomForest)

################################################################################
# Local dependencies
################################################################################

source ("R/common.R")

################################################################################
# Constants (change may be required for your own environment)
################################################################################

kSubmissionFileName <- "data/output/rforest.csv"

################################################################################
# Seed
################################################################################

set.seed(1994)

################################################################################
# Random Forest Specific Methods
################################################################################

BuildParamOutputsTable <- function() {
  validationFactors <- c(.25, .28, .3, .35)
  ntrees <- c(50, 80, 90, 100, 110, 120, 150, 180, 500, 1000, 5000)
  outputs <- CJ(validationFactors, ntrees)
  setnames(outputs, "V1", "validationFactor")
  setnames(outputs, "V2", "ntree")
  outputs[, score := 0]
  return (outputs)
}

PrintParams <- function (params=params) {
  print("params:")
  print(params)
}

PrintOutputs <- function (outputs=outputs) {
  print("outputs:")
  print(outputs)
}

PrintParamsOutput <- function (params=params, output=output) {
  print("params:")
  print(params)
  print("output.score:")
  print(output$score)
}

SaveOutput <- function(outputs, outputIndex, output) {
  outputs[outputIndex, score := output$score]
}

GetBestOutputParams <- function (results) {
  sortedOutputs <- results[order(-score)]
  return (sortedOutputs[1])
}

LoadTransform <- function(input=NULL, params=NULL) {
  output <- LoadPassengerData(validationFactor = params$validationFactor)
  return (output)
}

TrainTransform <- function(input=NULL, params=NULL) {
  train <- input$train
  train <- Normalize(train)
  fit <- randomForest(GetFormula(train),
                      data=train,
                      method="class",
                      ntree=params$ntree)

  output <- input
  output$train <- train
  output$fit <- fit

  return (output)
}

ValidateTransform <- function(input=NULL, params=NULL) {
  validation <- input$validation
  validation <- Normalize(validation)
  validation.result <- predict(input$fit, validation, type="class")

  output <- input
  output$validation <- validation
  output$validation.result <- validation.result

  return (output)
}

EvaluateTransform <- function(input=NULL, params=NULL) {
  score <- Evaluate(input$validation.result, input$validation[, survived])
  output <- input
  output$score <- score
  return (output)
}

TestTransform <- function(input=NULL, params=NULL) {
  test <- input$test
  test <- Normalize(test)
  test.result <- predict(input$fit, test, type="class")
  test.submission <- data.table(PassengerId=test[, passengerid], Survived=test.result)
  test.submission[ is.na(Survived), Survived := as.factor(0)]
  write.csv(test.submission, file=kSubmissionFileName, row.names=FALSE)

  output <- input
  output$test.result <- test.result
  output$test.submission <- test.submission

  return (output)
}

################################################################################
# Main Flow
################################################################################

outputs <- BuildParamOutputsTable()

for(outputIndex in 1:nrow(outputs)) {
  params <- outputs[outputIndex]

  output <- LoadTransform(params=params) %>%
    TrainTransform(input=., params=params) %>%
    ValidateTransform(input=., params=params) %>%
    EvaluateTransform(input=., params=params)

  PrintParamsOutput(params=params, output=output)
  SaveOutput(outputs, outputIndex, output)
}

PrintOutputs(output)
params <- GetBestOutputParams(outputs)
PrintParams(params)
output <- LoadTransform(params=params) %>%
  TrainTransform(input=., params=params) %>%
  ValidateTransform(input=., params=params) %>%
  TestTransform(input=., params=params)
