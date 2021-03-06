#### code to read and match 96-well plate data (sugar and starch concentrations)
#### and adult census data and do basic exploratory analyses

#load libraries
library(lme4)
library(ggplot2)

#helper functions
#function to find last value of vector
last <- function(x) { return( x[length(x)] ) }

#give sample size on boxplot for ggplot
give.n <- function(x){
  return(c(y = mean(x), label = length(x)))
}

#color-blind-friendly palettes
cbPalette <- c("#999999", "#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#D55E00", "#CC79A7")

#read data
#read Adult Census Data
adult <- read.csv("/Users/Josh/Dropbox/Dietze_Lab_Undergrads/JAM - Xsite/Field Data Entry/Data Sheets/Adult_Field_Data_JAM_MCD.csv")

#read NSC tracking data - contains sample mass used for assays
mass <- read.csv("/Users/Josh/Dropbox/NSC_Runs/All/Tracking/NSC_Mass_All.csv")

#all files starch files in one directory
data.dir.starch = "/Users/Josh/Dropbox/NSC_Runs/All/Starch"
data.dir.sugar = "/Users/Josh/Dropbox/NSC_Runs/All/Sugar"

#starch files
files.starch <- dir(data.dir.starch,"Xsite")
baseline.files.starch <- files.starch[grep(pattern = "Baseline",files.starch)]
HK.files.starch <- files.starch[grep(pattern = "HK",files.starch)]

baseline.starch = NULL
for(i in seq_along(baseline.files.starch)){
  tmp <- read.csv(file.path(data.dir.starch,baseline.files.starch[i]),sep="",colClasses="character")
  baseline.starch = rbind(baseline.starch,tmp)
}
mean.baseline.starch <- tapply(X = as.numeric(baseline.starch$Meas.), INDEX = baseline.starch$Sample, FUN = mean)
baseline.starch.id <- unique(baseline.starch$Sample)

#these files contain a run after Hexokinase is added
#measures starch content via breakdown of glucose & production of NADPH
HK.starch = NULL
for(i in seq_along(HK.files.starch)){
  tmp.HK.starch <- read.csv(file.path(data.dir.starch,HK.files.starch[i]),sep="",colClasses="character")
  HK.starch = rbind(HK.starch,tmp.HK.starch)
}
max.HK.starch <- tapply(X = as.numeric(HK.starch$Meas.), INDEX = HK.starch$Sample, FUN = max)
HK.starch.id <- unique(HK.starch$Sample)

# Check that samples finished converting all Starch. If not, flag for reanalysis
dif.HK.starch <- tapply(X = as.numeric(HK.starch$Meas.), INDEX = HK.starch$Sample, FUN = diff)

#difference between baseline and HK
total.starch <- max.HK.starch-mean.baseline.starch

##TODO use each standard curve for each individual plate
##currenlty only using one standard curve
#create standard curve equation

standard.abs.starch <- c(mean(total.starch[3:4]),mean(total.starch[1:2]),
                         mean(total.starch[5:6]),mean(total.starch[7:8]))
#standard.conc.starch <- c(0,0.5,1.0,1.5) #standard glucose concentrations in mmol for plate 2
standard.conc.starch <- c(0,20,40,60) #standard concentrations * 40 uL
standard.lm.starch <- lm(standard.abs.starch ~ standard.conc.starch)
summary(standard.lm.starch) #slope, intercept, R^2

#visualize standard curve
plot(standard.conc.starch,standard.abs.starch)
abline(standard.lm.starch)

#standard curve equation - calculate mmol glucose equivalents of samples
sample.conc.starch <- (total.starch - standard.lm.starch$coefficients[1])/standard.lm.starch$coefficients[2]
sample.conc.starch <- as.matrix(sample.conc.starch)
sample.ids.starch <- strsplit(row.names(sample.conc.starch),"_")

###create ID to match Core_ID in adult census data
core.id.starch <- array()
for(i in 1:length(sample.conc.starch)){
  core.id.starch[i] <- paste0(sample.ids.starch[[i]][1],
                              sample.ids.starch[[i]][2],
                              sample.ids.starch[[i]][3])
}

##bind core.id to sample matrix
sample.starch <- data.frame(core.id.starch,sample.conc.starch)
sample.agg.starch <- aggregate(sample.conc.starch~core.id.starch,sample.starch,mean)
matches.starch <- match(as.character(sample.agg.starch$core.id),as.character(adult$Core_ID14))
row.names(sample.agg.starch) <- NULL
nsc.adult.dat.starch <- data.frame(sample.agg.starch,adult[matches.starch,])

#match sample masses to absorbance
matches.mass.starch <- match(as.character(nsc.adult.dat.starch$Core_ID14),as.character(mass$Core_ID))
nsc.adult.starch.mass <- data.frame(nsc.adult.dat.starch,mass[matches.mass.starch,])

#mass column is Mass_mg
#calculate concentrations based on mass of sample used
nsc.adult.starch.mass$ug.sample <- nsc.adult.starch.mass$sample.conc.starch / 40 * 840 #micrograms/sample 40 ul drawn from 840 ul total volume of Starch Extraction
nsc.adult.starch.mass$Starch.mg.g <- nsc.adult.starch.mass$ug.sample / nsc.adult.starch.mass$Mass_mg #mg/gram of sample

############ Sugar Files ############
files.sugar <- dir(data.dir.sugar,"Xsite")
baseline.files.sugar <- files.sugar[grep(pattern = "Baseline", files.sugar)]
glucose.files.sugar <- files.sugar[grep(pattern = "Glucose", files.sugar)]
fructose.files.sugar <- files.sugar[grep(pattern = "Fructose", files.sugar)]
sucrose.files.sugar <- files.sugar[grep(pattern = "Sucrose", files.sugar)]

baseline.sugar = NULL
for(i in seq_along(baseline.files.sugar)){
  tmp <- read.csv(file.path(data.dir.sugar,baseline.files.sugar[i]),sep="",colClasses="character")
  baseline.sugar = rbind(baseline.sugar,tmp)
}
mean.baseline.sugar <- tapply(X = as.numeric(baseline.sugar$Meas.), INDEX = baseline.sugar$Sample, FUN = mean) #consider replacing mean with last
baseline.sugar.id <- unique(baseline.sugar$Sample)

#these files contain a run after Hexokinase is added
#measures sugar content via breakdown of glucose & production of NADPH
glucose.sugar = NULL
for(i in seq_along(glucose.files.sugar)){
  tmp.glucose <- read.csv(file.path(data.dir.sugar,glucose.files.sugar[i]),sep="",colClasses="character")
  glucose.sugar = rbind(glucose.sugar,tmp.glucose)
}
max.glucose.sugar <- tapply(X = as.numeric(glucose.sugar$Meas.), INDEX = glucose.sugar$Sample, FUN = max)
glucose.sugar.id <- unique(glucose.sugar$Sample)

#difference between baseline and HK (glucose content)
total.glucose <- max.glucose.sugar-mean.baseline.sugar

#these files contain  a run after hexokinase and PGI have been added
#measures sugar content via breakdown of fructose & production of NADPH
fructose.sugar = NULL
for(i in seq_along(fructose.files.sugar)){
  tmp.fructose <- read.csv(file.path(data.dir.sugar,fructose.files.sugar[i]),sep="",colClasses="character")
  fructose.sugar = rbind(fructose.sugar,tmp.fructose)
}
max.fructose.sugar <- tapply(X = as.numeric(fructose.sugar$Meas.), INDEX = fructose.sugar$Sample, FUN = max)
fructose.sugar.id <- unique(fructose.sugar$Sample)

#difference between HK and PGI (Fructose content)
last.glucose.sugar <- tapply(X = as.numeric(glucose.sugar$Meas.), INDEX = glucose.sugar$Sample, FUN = last)
total.fructose <- max.fructose.sugar-last.glucose.sugar

#these files contain  a run after hexokinase, PGI and Invertase have been added
#measures sugar content via breakdown of sucrose & production of NADPH
sucrose.sugar = NULL
for(i in seq_along(sucrose.files.sugar)){
  tmp.sucrose <- read.csv(file.path(data.dir.sugar,sucrose.files.sugar[i]),sep="",colClasses="character")
  sucrose.sugar = rbind(sucrose.sugar,tmp.sucrose)
}
max.sucrose.sugar <- tapply(X = as.numeric(sucrose.sugar$Meas.), INDEX = sucrose.sugar$Sample, FUN = max)
sucrose.sugar.id <- unique(sucrose.sugar$Sample)

#difference between HK and PGI (Fructose content)
last.fructose.sugar <- tapply(X = as.numeric(fructose.sugar$Meas.), INDEX = fructose.sugar$Sample, FUN = last)
total.sucrose <- max.sucrose.sugar-last.fructose.sugar

##TODO use each standard curve for each individual plate
##currenlty only using one standard curve
#create standard curve equation

standard.abs.sugar <- c(mean(total.glucose[3:4]),mean(total.glucose[1:2]),
                        mean(total.glucose[5:6]),mean(total.glucose[7:8]))
#standard.conc.starch <- c(0,0.5,1.0,1.5) #standard glucose concentrations in mmol for plate 2
standard.conc.sugar <- c(0,20,40,60) #standard concentrations * 40 uL
standard.lm.sugar <- lm(standard.abs.sugar ~ standard.conc.sugar)
summary(standard.lm.sugar) #slope, intercept, R^2

#visualize standard curve
plot(standard.conc.sugar,standard.abs.sugar)
abline(standard.lm.sugar)

#standard curve equation - calculate mmol glucose equivalents of samples
sample.conc.glucose <- ((total.glucose) - standard.lm.sugar$coefficients[1])/standard.lm.sugar$coefficients[2] #only 20ul of sample was used, compared to 40ul of standard
sample.conc.glucose <- as.matrix(sample.conc.glucose)
sample.ids.glucose <- strsplit(row.names(sample.conc.glucose),"_")

sample.conc.fructose <- ((total.fructose) - standard.lm.sugar$coefficients[1])/standard.lm.sugar$coefficients[2] #only 20ul of sample was used, compared to 40ul of standard
sample.conc.fructose <- as.matrix(sample.conc.fructose)
sample.ids.fructose <- strsplit(row.names(sample.conc.fructose),"_")

sample.conc.sucrose <- ((total.sucrose) - standard.lm.sugar$coefficients[1])/standard.lm.sugar$coefficients[2] #only 20ul of sample was used, compared to 40ul of standard
sample.conc.sucrose <- as.matrix(sample.conc.sucrose)
sample.ids.sucrose <- strsplit(row.names(sample.conc.sucrose),"_")

###create ID to match Core_ID in adult census data
core.id.sugar <- array()
for(i in 1:length(sample.conc.glucose)){
  core.id.sugar[i] <- paste0(sample.ids.glucose[[i]][1],
                             sample.ids.glucose[[i]][2],
                             sample.ids.glucose[[i]][3])
}

##bind core.id to sample matrix
sample.sugar <- data.frame(core.id.sugar,sample.conc.glucose,sample.conc.fructose,sample.conc.sucrose)
sample.agg.glucose <- aggregate(sample.conc.glucose ~ core.id.sugar, sample.sugar, mean)
sample.agg.fructose <- aggregate(sample.conc.fructose ~ core.id.sugar, sample.sugar, mean)
sample.agg.sucrose <- aggregate(sample.conc.sucrose ~ core.id.sugar, sample.sugar, mean)
sample.agg.sugar <- data.frame(sample.agg.glucose$core.id.sugar, sample.agg.glucose$sample.conc.glucose,
                               sample.agg.fructose$sample.conc.fructose, sample.agg.sucrose$sample.conc.sucrose)

matches.sugar <- match(as.character(sample.agg.sugar$sample.agg.glucose.core.id),as.character(adult$Core_ID14))
row.names(sample.agg.sugar) <- NULL
nsc.adult.dat.sugar <- data.frame(sample.agg.sugar,adult[matches.sugar,])

#match sample masses to absorbance
matches.mass.sugar <- match(as.character(nsc.adult.dat.sugar$Core_ID14),as.character(mass$Core_ID))
nsc.adult.sugar.mass <- data.frame(nsc.adult.dat.sugar,mass[matches.mass.sugar,])

#mass column is Mass_mg
#calculate concentrations of glucose based on mass of sample used
nsc.adult.sugar.mass$ug.glucose <- nsc.adult.sugar.mass$sample.agg.glucose.sample.conc.glucose / 20 * 845 #micrograms/sample 20 ul drawn from 845 ul total volume of Sugar Extraction
nsc.adult.sugar.mass$glucose.mg.g <- nsc.adult.sugar.mass$ug.glucose / nsc.adult.sugar.mass$Mass_mg #mg/gram of sample

#calculate concentrations of fructose based on mass of sample used
nsc.adult.sugar.mass$ug.fructose <- nsc.adult.sugar.mass$sample.agg.fructose.sample.conc.fructose / 20 * 845 #micrograms/sample 20 ul drawn from 845 ul total volume of Sugar Extraction
nsc.adult.sugar.mass$fructose.mg.g <- nsc.adult.sugar.mass$ug.fructose / nsc.adult.sugar.mass$Mass_mg #mg/gram of sample

#calculate concentrations of fructose based on mass of sample used
nsc.adult.sugar.mass$ug.sucrose <- nsc.adult.sugar.mass$sample.agg.sucrose.sample.conc.sucrose / 20 * 845 #micrograms/sample 20 ul drawn from 845 ul total volume of Sugar Extraction
nsc.adult.sugar.mass$sucrose.mg.g <- nsc.adult.sugar.mass$ug.sucrose / nsc.adult.sugar.mass$Mass_mg #mg/gram of sample

###########Combine Sugar and Starch for total NSC, far fewer samples##############
starch.only <- data.frame(nsc.adult.starch.mass$core.id.starch,nsc.adult.starch.mass$Starch.mg.g)
matches.sugar.starch <- match(as.character(nsc.adult.sugar.mass$sample.agg.glucose.core.id.sugar),
                              as.character(starch.only$nsc.adult.starch.mass.core.id.starch))
row.names(nsc.adult.sugar.mass) <- NULL
row.names(starch.only) <- NULL
nsc.adult.total.mass <- data.frame(nsc.adult.sugar.mass,starch.only[matches.sugar.starch,])
nsc.adult.total.mass$total.nsc <- mapply(nsc.adult.total.mass$nsc.adult.starch.mass.Starch.mg.g,
                                         nsc.adult.total.mass$glucose.mg.g,
                                         nsc.adult.total.mass$fructose.mg.g,
                                         nsc.adult.total.mass$sucrose.mg.g, FUN=sum, na.rm=FALSE)                                      
#rename starch column
colnames(nsc.adult.total.mass)[115] <- "core.id.starch"
colnames(nsc.adult.total.mass)[116] <- "starch.mg.g"

#remove NAs for total.nsc
nsc.adult.total.mass <- nsc.adult.total.mass[which(nsc.adult.total.mass$total.nsc != "NA"),]