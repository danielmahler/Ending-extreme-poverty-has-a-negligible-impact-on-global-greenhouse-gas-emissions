#####################################
### INSTALLING NECESSARY PACKAGES ###
#####################################
#install.packages("haven")
#install.packages("rgdal")
#install.packages("ggplot2")
{
suppressMessages(library(rgdal))
suppressMessages(require("plyr"))
library(scales)
library(haven)
library(haven)
library(ggplot2)
}

setwd("C:/Users/WB514665/OneDrive - WBG/Research/Poverty-climate")
rm(list=ls())

#################
### LOAD DATA ###
#################
# Load poverty data
poverty = read_dta("02-Intermediatedata/Poverty_rates.dta")
# Load shapefile
load(file = "01-Inputdata/Maps/WorldShapefile.rda")
# Merge
names(poverty)[names(poverty)=="code"] <- "ISO_CODES"
mergedfile <- join(poverty,WorldShapefile,by="ISO_CODES", type="full")

############################
### CREATE COLOR SCHEMES ###
############################
LOW  = "#56B4E9"
HIGH = "#000000"
MID  = "#005a89"
colors = c("#000000","#E69F00","#009E73","#56B4E9","grey")

#################
### PLOT MAPS ###
#################
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
  ggsave(file="05-Figures/Maps/Category.jpg", width=12,height=7,units="in",dpi=1000)

map = ggplot() +
    geom_polygon(data = mergedfile, aes(x = long, y = lat, group = group, fill=rate215), color = 'white',size=0.1) + 
    scale_fill_gradient2(low = LOW, mid = MID,high = HIGH, midpoint=25, oob=squish, name="Poverty rate (%)") +
    theme(panel.background = element_rect(fill='white', color='white')) +
    theme(axis.title.x=element_blank(), axis.text.x=element_blank(), axis.ticks.x=element_blank()) +
    theme(axis.title.y=element_blank(), axis.text.y=element_blank(), axis.ticks.y=element_blank()) +
    theme(plot.title=element_text(hjust=0.5),plot.subtitle=element_text(hjust=0.5))
  plot(map)
  ggsave(file="05-Figures/Maps/215.jpg", width=12,height=6,units="in",dpi=1000)
  
map = ggplot() +
    geom_polygon(data = mergedfile, aes(x = long, y = lat, group = group, fill=rate365), color = 'white',size=0.1) + 
    scale_fill_gradient2(low = LOW, mid = MID,high = HIGH, midpoint=25, oob=squish, name="Poverty rate (%)") +
    theme(panel.background = element_rect(fill='white', color='white')) +
    theme(axis.title.x=element_blank(), axis.text.x=element_blank(), axis.ticks.x=element_blank()) +
    theme(axis.title.y=element_blank(), axis.text.y=element_blank(), axis.ticks.y=element_blank()) +
    theme(plot.title=element_text(hjust=0.5),plot.subtitle=element_text(hjust=0.5))
  plot(map)
  ggsave(file="05-Figures/Maps/365.jpg", width=12,height=6,units="in",dpi=1000)
  
map = ggplot() +
    geom_polygon(data = mergedfile, aes(x = long, y = lat, group = group, fill=rate685), color = 'white',size=0.1) + 
    scale_fill_gradient2(low = LOW, mid = MID,high = HIGH, midpoint=25, oob=squish, name="Poverty rate (%)") +
    theme(panel.background = element_rect(fill='white', color='white')) +
    theme(axis.title.x=element_blank(), axis.text.x=element_blank(), axis.ticks.x=element_blank()) +
    theme(axis.title.y=element_blank(), axis.text.y=element_blank(), axis.ticks.y=element_blank()) +
    theme(plot.title=element_text(hjust=0.5),plot.subtitle=element_text(hjust=0.5))
  plot(map)
  ggsave(file="05-Figures/Maps/685.jpg", width=12,height=6,units="in",dpi=1000)
  
    