####################
### INTRODUCTION ###
####################
# This file produces the beeswarm plot
setwd("C:/Users/WB514665/OneDrive - WBG/Research/Poverty-climate_public")

#####################################
### INSTALLING NECESSARY PACKAGES ###
#####################################
#install.packages("haven")
#install.packages("dplyr")
#install.packages("beeswarm")
library(dplyr)

####################
### PREPARE DATA ###
####################
# Load consumption distributions
data <- haven::read_dta("02-Intermediatedata/Consumptiondistributions.dta") %>% 
# Only keep Benin
        filter(code=="BEN") %>% 
# Only keep relevant variables
        select(c("quantile","consumption")) %>% 
# Collapse to 100 percentiles
        mutate(pctl = round(seq(1:1000)/10+0.499)) %>% 
        rename("baseline"="consumption") %>% 
        group_by(pctl) %>%
# Create baseline scenario
        summarise(baseline = mean(baseline),.groups = 'drop') %>% 
# Create distribution-neutral growth scenario
        mutate(poverty3      = baseline*1.62) %>% 
# Create gini-reducing scenario
        mutate(poverty3gini10 = ((1-0.1)*baseline+0.1*mean(baseline))*1.26) %>% 
# Reshape
        tidyr::pivot_longer(cols=c("baseline","poverty3","poverty3gini10"),names_to="case",values_to="welf")

#####################
### PLOT BEESWARM ###
#####################
# Specify font
windowsFonts(A = windowsFont("Arial")) 
setEPS()
postscript("05-Figures/ExtendedDataFigure1.eps",width=10,heigh=5)
#jpeg("05-Figures/ExtendedDataFigure1.jpg", width=10,height=5,units="in",res=300)
beeswarm::beeswarm(log(data$welf)~data$case, 
         pch=19, 
         ylab="Daily consumption per person (2017 USD)",
         col = c("#000000"),
         xlab="",
         axes=FALSE,
         corral="wrap",
         cex.axis = 0.5)
axis(2, at=c(log(1),log(2.15),log(5),log(10),log(20),log(50)), labels=c(1,2.15,5,10,20,50),las=1)
axis(1, at=c(0,1,2,3,4), labels=c("","Benin 2022","With 62% growth", " \n With 26% growth, \n 10% decrease in Gini",""), col.ticks = "white")
abline(h=log(2.15), col="gray")
dev.off()

# Store source data
sourcedata <- data %>% 
mutate(Scenario = case_when(case=="baseline" ~ "Benin 2022",
                              case=="poverty3" ~ "Benin 2022 with 62% growth",
                              case=="poverty3gini10" ~ "Benin 2022 with 26% growth, 10% decrease in Gini")) %>% 
  select(Scenario,welf,pctl) %>% 
  rename("Consumption ($/day, 2017 PPP)" = "welf","Percentile"="pctl")

  
       
openxlsx::write.xlsx(sourcedata, file="05-Figures/SourceData.xlsx",sheetName = "ExtendedDataFigure1",colnames = TRUE, append=TRUE)

