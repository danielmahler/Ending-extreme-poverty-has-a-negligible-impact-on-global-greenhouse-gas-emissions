####################
### INTRODUCTION ###
####################

# This file produces a map indicating whether countries have achieved the poverty target at a given line

##################################
### INSTALL NECESSARY PACKAGES ###
##################################
#install.packages("haven")
#install.packages("ggplot2")
#install.packages("dplyr")
#install.packages("openxlsx")
library(ggplot2)
library(dplyr)

############################
### PREPARE POVERTY DATA ###
############################
# Load consumption distributions
poverty <- haven::read_dta("02-Intermediatedata/Consumptiondistributions.dta") %>% 
# Create poverty indicators for each line
mutate(rate215 = consumption<2.15, rate365 = consumption<3.65, rate685 = consumption<6.85) %>% 
# Collapse to poverty rates for each country
  group_by(code) %>%
  summarise(across(c(rate215, rate365, rate685),mean),
            .groups = 'drop') %>%
  as.data.frame() %>% 
# Construct indicator for the highest line at which the poverty target has been met
  mutate(poor215 = rate215>0.03, poor365 = rate365>0.03, poor685 = rate685>0.03) %>% 
  mutate(category = case_when(poor215==1 ~ 1,
                              poor365==1 & poor215==0 ~ 2,
                              poor685==1 & poor365==0 ~ 3,
                              poor685==0 ~ 4))

############################
### MERGE WITH SHAPEFILE ###
############################
# Load shapefile
load(file = "01-Inputdata/Maps/WorldShapefile.rda")
# Merge
names(poverty)[names(poverty)=="code"] <- "ISO_CODES"
mergedfile <- full_join(poverty,WorldShapefile,by="ISO_CODES")
# Create color scheme
colors = c("#000000","#E69F00","#009E73","#56B4E9","grey")

################
### PLOT MAP ###
################
  map = ggplot() +
  geom_polygon(data = mergedfile, aes(x = long, y = lat, group = group, fill=as.factor(category)), color = 'white',size=0.1) + 
    scale_fill_manual(values=colors, name="", labels = c("Target not met at $2.15 (more than 3% below the $2.15 extreme poverty line)", 
                                                                           "Target met at $2.15, but not at $3.65 (more than 3% below the $3.65 poverty line)", 
                                                                           "Target met at $3.65, but not at $6.85 (more than 3% below the $6.85 poverty line)", 
                                                                           "Target met at $6.85 (less than 3% below the $6.85 poverty line)","N/A","","N/A")) +
    theme(panel.background = element_rect(fill='white', color='white')) +
    theme(axis.title.x=element_blank(), axis.text.x=element_blank(), axis.ticks.x=element_blank()) +
    theme(axis.title.y=element_blank(), axis.text.y=element_blank(), axis.ticks.y=element_blank()) +
    theme(plot.title=element_text(hjust=0.5),plot.subtitle=element_text(hjust=0.5)) +
    theme(legend.position="bottom") + guides(fill=guide_legend(nrow=3,byrow=TRUE))
  plot(map)
  # Save figure
  ggsave(map, file="05-Figures/ExtendedDataFigure2a.jpg", width=12,height=7,units="in",dpi=200)
  ggsave(map, file="05-Figures/ExtendedDataFigure2a.eps", device="eps", units="mm",width=183, height=183/12*7, dpi=200)
  # Store source data
  sourcedata <- poverty %>% 
  mutate(Category = case_when(category==1 ~ "Target not met at $2.15 (more than 3% below the $2.15 extreme poverty line)",
                              category==2 ~ "Target met at $2.15, but not at $3.65 (more than 3% below the $3.65 poverty line)",
                              category==3 ~ "Target met at $3.65, but not at $6.85 (more than 3% below the $6.85 poverty line)",
                              category==4 ~ "Target met at $6.85 (less than 3% below the $6.85 poverty line)")) %>% 
  select(ISO_CODES,Category) %>% 
  rename("Country code"="ISO_CODES")
  openxlsx::write.xlsx(sourcedata, file="05-Figures/SourceData.xlsx",sheetName = "ExtendedDataFigure2a",colnames = TRUE)
  