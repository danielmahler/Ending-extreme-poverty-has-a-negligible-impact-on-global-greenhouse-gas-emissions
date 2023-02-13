#install.packages("beeswarm")
library(beeswarm)
rm(list=ls())
setwd("C:/Users/WB514665/OneDrive - WBG/Research/Poverty-climate/")

##############
### SLIDES ###
##############

data = read.csv("02-Intermediatedata/Beeswarm.csv")

plot1 = data[data$case=="baseline" | data$case=="fiction",]
tiff("05-Figures/Beeswarm_Kenya1.tiff", width = 6, height = 5, units = 'in', res = 200)
beeswarm(log(plot1$welfKEN)~plot1$case, 
         pch=19, 
         col = c("#3FA0FF", "#FFE099"),
         ylab="Daily consumption per person (2017 USD)",
         xlab="",
         pwcol = ifelse(plot1$welfKEN<2.14,1,2),
         axes=FALSE,
         corral="wrap")
axis(2, at=c(log(0.25),log(0.5),log(1),log(2.15),log(5),log(10),log(20),log(50)), labels=c(0.25,0.5,1,2.15,5,10,20,50),las=1)
axis(1, at=c(0,1,2,3), labels=c("","Kenya 2022","Future Kenya?",""))
abline(h=log(2.15), col="gray")
dev.off()

plot2 = data[data$case=="1999" | data$case=="2015",]
tiff("05-Figures/Beeswarm_Tajikistan.tiff", width = 6, height = 5, units = 'in', res = 200)
beeswarm(log(plot2$welfTJK)~plot2$case, 
         pch=19, 
         col = c("#3FA0FF", "#FFE099"),
         ylab="Daily consumption per person (2017 USD)",
         xlab="",
         pwcol = ifelse(plot2$welfTJK<2.14,1,2),
         axes=FALSE,
         corral="wrap")
axis(2, at=c(log(0.25),log(0.5),log(1),log(2.15),log(5),log(10),log(20),log(50)), labels=c(0.25,0.5,1,2.15,5,10,20,50),las=1)
axis(1, at=c(0,1,2,3), labels=c("","Tajikistan 1999","Tajikistan 2015",""))
abline(h=log(2.15), col="gray")
dev.off()

plot3 = data[data$case=="baseline" | data$case=="3",]
plot3$case[plot3$case=="3"] = "c"
tiff("05-Figures/Beeswarm_Kenya2.tiff", width = 6, height = 5, units = 'in', res = 200)
beeswarm(log(plot3$welfKEN)~plot3$case, 
         pch=19, 
         col = c("#3FA0FF", "#FFE099"),
         ylab="Daily consumption per person (2017 USD)",
         xlab="",
         pwcol = ifelse(plot3$welfKEN<2.14,1,2),
         axes=FALSE,
         corral="wrap")
axis(2, at=c(log(0.25),log(0.5),log(1),log(1.9),log(5),log(10),log(20),log(50)), labels=c(0.25,0.5,1,2.15,5,10,20,50),las=1)
axis(1, at=c(0,1,2,3), labels=c("","Kenya 2022","With 100% growth",""))
abline(h=log(2.15), col="gray")
dev.off()

plot4 = data[data$case=="baseline"  | data$case=="fiction" | data$case=="3",]
plot4$case[plot4$case=="3"] = "g"

tiff("ClimatePoverty/KEN3.tiff", width = 8, height = 5, units = 'in', res = 200)
beeswarm(log(plot4$welfKEN)~plot4$case, 
         pch=19, 
         col = c("#3FA0FF", "#FFE099"),
         ylab="Daily consumption per person (2017 USD)",
         xlab="",
         pwcol = ifelse(plot4$welfKEN<2.14,1,2),
         axes=FALSE,
         corral="wrap")
axis(2, at=c(log(0.25),log(0.5),log(1),log(1.9),log(5),log(10),log(20),log(50)), labels=c(0.25,0.5,1,1.9,5,10,20,50),las=1)
axis(1, at=c(0,1,2,3,4), labels=c("","Kenya 2022","Moving all poor \n to the poverty line", "With 136% growth",""), col.ticks = "white")
abline(h=log(1.9), col="gray")
dev.off()

plot5 = data[data$case=="baseline" | data$case=="3" | data$case=="3gini5",]
plot5$case[plot5$case=="3"] = "c"
plot5$case[plot5$case=="3gini5"] = "d"

tiff("ClimatePoverty/KEN4.tiff", width = 8, height = 5, units = 'in', res = 200)
beeswarm(log(plot5$welfKEN)~plot5$case, 
         pch=19, 
         col = c("#3FA0FF", "#FFE099"),
         ylab="Daily consumption per person (2011 USD)",
         xlab="",
         pwcol = ifelse(plot5$welfKEN<1.89,1,2),
         axes=FALSE,
         corral="wrap")
axis(2, at=c(log(0.25),log(0.5),log(1),log(1.9),log(5),log(10),log(20),log(50)), labels=c(0.25,0.5,1,1.9,5,10,20,50),las=1)
axis(1, at=c(0,1,2,3,4), labels=c("","Kenya 2020","With 136% growth", " \n With 101% growth, \n 5% decrease in Gini",""), col.ticks = "white")
abline(h=log(1.9), col="gray")
dev.off()

##############
### PAPER ###
##############
data = read.csv("02-Intermediatedata/Beeswarm_paper.csv")
windowsFonts(A = windowsFont("Arial"))  # Specify font

data$color = "#000000"
data$color[data$welfBEN<2.15] = "#E69F00"
colors <- as.character(data$color)


tiff("05-Figures/Beeswarm_Benin.tiff", width = 8, height = 5, units = 'in', res = 200)
beeswarm(log(data$welfBEN)~data$case, 
         pch=19, 
         ylab="Daily consumption per person (2017 USD)",
         col = c("#000000"),
         xlab="",
         axes=FALSE,
         corral="wrap")
axis(2, at=c(log(1),log(2.15),log(5),log(10),log(20),log(50)), labels=c(1,2.15,5,10,20,50),las=1)
axis(1, at=c(0,1,2,3,4), labels=c("","Benin 2022","With 62% growth", " \n With 26% growth, \n 10% decrease in Gini",""), col.ticks = "white")
abline(h=log(2.15), col="gray")
dev.off()
