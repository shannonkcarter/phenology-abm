#############################################################
###-----------------PREP WORKSPACE------------------------###
#############################################################

## Set working directory and clear memory
setwd("C:\\Users\\Shannon\\Google Drive\\Synchrony_NetLogo")
rm(list = ls(all = T))

## Load required packages
library(tidyverse)
library(reshape2)
library(RColorBrewer)
library(lme4)
#library(RNetLogo)    # maybe worthwhile looking into this, so far can't figure it out

## Load universal plotting elements
mytheme <- theme(panel.background = element_blank(),
                 panel.grid.minor = element_blank(), 
                 panel.grid.major = element_blank(),
                 axis.text  = element_text(size = rel(1.3), colour = "black"),
                 axis.title = element_text(size = rel(2.0)),
                 axis.line  = element_line(colour = "black"))

#############################################################
###-------------LOAD AND PROCESS RAW DATA-----------------###
#############################################################

###---TEST7LONG: LONG FORMAT, ONE LINE PER TICK PER TURT-----

## Load raw data
test7raw <- read.csv("test7_forR.csv", header = T, check.names = F)

## Make long format and label tick and size columns
test7long <- melt(test7raw, id.vars = c("sync", "dens", "rep", "turt"))           
names(test7long) <- c("sync", "dens", "rep", "turt", "tick", "size")

## Change data str
test7long$tick <- as.integer(test7long$tick)
test7long$turt <- as.factor(test7long$turt)
test7long$rep  <- as.factor(test7long$rep)

## Retrieve hatch-tick, max size, growth rate, and meta-tick for each turt
test7long <- test7long %>%
  group_by(sync, dens, rep, turt) %>%
  mutate(hatch_tick = tick[min(which(size == 1))],
         maxsize = max(na.omit(size)),
         growthrate =  maxsize/(tick[min(which(size == maxsize))] - hatch_tick),
         meta_tick = ifelse(maxsize >= 10, tick[min(which(size == 10))], NA)) 

## Infinite growth rate actually means it never grew
test7long$growthrate[is.infinite(test7long$growthrate)] <- 0

## Bin hatch-ticks into cohorts
test7long$cohort <- .bincode(test7long$hatch_tick, c(seq(8, 60, 5)))
test7long$cohort <- as.factor(test7long$cohort)

## Turn max size into a binary for metamorphosis
test7long$meta <- ifelse(test7long$maxsize >= 10, 1, 0)

## Save long format data
write.csv(test7long, "test7long.csv")

###---TEST7SUM: ONE LINE PER TURT----------------------------

## Delete redundant lines-- 1 line per turt
test7sum <- select(test7long, sync, dens, rep, turt, hatch_tick, maxsize, meta_tick, growthrate, cohort, meta)
test7sum <- unique(test7sum)

## Make a trt var including sync and dens
test7sum$trt <- paste(test7sum$sync, test7sum$dens)

## Write out sync and dens trt levels for figures
test7sum$synchrony <- factor(test7sum$sync,
                             levels = c("1", "3", "5", "7"),
                             labels = c("high synchrony", "med-hi synchrony", "med-lo synchrony", "low synchrony"))
test7sum$density <- factor(test7sum$dens,
                           levels = c("40", "80", "120"),
                           labels = c("low density", "med density", "high density"))

## Add a variable for minimum meta and hatch dates in each treatment & standardize to the first in each trt
test7sum <- test7sum %>%
  group_by(trt) %>%
  mutate(hatch_min = min(hatch_tick),
         meta_min  = min(meta_tick, na.rm = T),
         hatch_adj = hatch_tick - hatch_min,
         meta_adj  = meta_tick - meta_min)

## Write to a csv file
write.csv(test7sum, "test7sum.csv")

###---TEST7SUPERSUM: ONE LINE PER TRTmutate ------------------------

## Load raw data
test7supersum <- read.csv("test7supersummary.csv", header = T)

## Write out synchrony and density levels for figures
test7supersum$synchrony <- factor(test7supersum$sync,
                                  levels = c("1", "3", "5", "7"),
                                  labels = c("high synchrony", "med-hi synchrony", "med-lo synchron", "low synchrony"))
test7supersum$density <- factor(test7supersum$dens,
                                levels = c("40", "80", "120"),
                                labels = c("low density", "med density", "high density"))
test7supersum$density <- as.factor(test7supersum$density)

## Add proportional survival, scaled to density
test7supersum$prop_surv <- test7supersum$n_meta/test7supersum$dens

## Add the minimum survival to each row so I can standardize for better plotting
test7supersum <- test7supersum %>%
  group_by(dens) %>%
  mutate(min_surv = mean(prop_surv[synchrony = 1]))

## Re-write to a csv file
write.csv(test7supersum, "test7supersum.csv")



#############################################################
###----------LOAD DATA FOR PLOTS & ANALYSIS---------------###
#############################################################

## Test7raw: Wide format raw data. 4 Sync (1, 3, 5, 7) x 3 Dens (40, 80, 120), 5 rep
test7raw <- read.csv("test7_forR.csv", header = T, check.names = F)

## Test7long: One row per tick per turtle-- individual size data throughout exp
test7long <- read.csv("test7long.csv", header = T)

## Test7sum: One row per turtle-- individual hatch, growth, survival data
test7sum <- read.csv("test7sum.csv", header = T)

## Test7supersum: One row per treatment-- n-meta data per trt
test7supersum <- read.csv("test7supersum.csv", header = T)

## Test8supersum: One row per trt-- Synchrony x Density gradient, 10 rep
test8supersum <- read.csv("test8_forR.csv", header = T, check.names = F)

#############################################################
###---------------------PLOTS-----------------------------###
#############################################################

###---2. Linear growth---------------------------------------
test7long$cohort <- as.factor(test7long$cohort)
plot2 <- ggplot(test7long, aes(x = tick, y = size, group=interaction(cohort,turt), color = cohort)) + 
  geom_point(size = 1, alpha = 0.2) + 
  stat_smooth(alpha = 0.1, se = F, size = 1, method = "lm") + 
  facet_grid(dens ~ sync, scales = 'free') + mytheme 
plot2

###---3. Final size by hatch tick-----------------------------
plot3 <- ggplot(test7sum, aes(x = hatch_tick, y = maxsize)) +
  geom_point(size = 1, alpha = 0.2, position = 'jitter') +
  stat_smooth(method = 'lm', se = T, size = 2) +
  facet_grid(dens ~ sync, scales = 'free') + mytheme
plot3

###---4. Survival probability plots---------------------------
plot4 <- ggplot(test7sum, aes(x = hatch_tick, y = meta)) + 
  geom_point(alpha = 0.25) + 
  stat_smooth(method = 'glm', method.args = 'binomial') +
  facet_grid(density ~ synchrony, scales = "free") + 
  xlab("hatch date") + ylab("probability of survival") +
  theme(strip.text.x = element_text(size = 14),
        strip.text.y = element_text(size = 14)) +
  mytheme
plot4

###---5. N_meta by treatment--------------------------------------

test8supersum$density <- as.factor(test8supersum$dens)
test7supersum$density <- factor(test7supersum$density, levels = c('low density', 'med density', 'high density'))

plot5 <- ggplot(test7supersum, aes(x = sync, y = prop_surv - min_surv, color = density)) + mytheme +
  geom_jitter(width = 0.25, size = 4) + 
  stat_smooth(size = 4, method = "lm", se = T, aes(x = sync, fill = density)) +
  xlab("synchrony") + ylab("proportion survivors (relative to sync = 1)") #+
  #theme(legend.position = "none") 
plot5

# Med density only
plot5 <- ggplot(subset(test7supersum, subset = (dens == 80)), aes(x = sync, y = prop_surv)) + mytheme +
  geom_jitter(width = 0.25, size = 4, color = "springgreen4", alpha = 0.25) + 
  stat_smooth(size = 4, color = 'springgreen4', fill = 'springgreen4', method = "lm", se = T) +
  xlab("synchrony") + ylab("proportion survivors") +
  theme(axis.text.x = element_blank())
plot5


plot5a <- ggplot(test7supersum, aes(x = sync, y = prop_surv, color = density)) + mytheme +
  geom_point(size = 3) + 
  stat_smooth(size = 2, method = 'lm', se = T, aes(x = sync, fill = density)) #+
  facet_grid(dens ~ ., scales = 'free')
plot5a

plot5x <- ggplot(test8supersum, aes(x = dens, y = n_meta/dens, color = as.factor(sync))) +# mytheme +
  geom_point() +
  stat_smooth(size = 2, se = F)
plot5x

###---6. Synchrony across stages-----------------------------

## Subset to include only individuals that metamorphed
test7surv <- subset(test7sum, subset = (meta == 1))

## Original hatching and metamorph
plot6 <- ggplot(test7sum, aes(hatch_adj)) + mytheme +
  # gray: original/imposed hatching synchrony
  geom_density(size = 1.5, alpha = 0.25, fill = "black", color = "gray39", linetype = "dashed") + 
  # blue: metamorphosis dates of survivors, scaled to day 0
  geom_density(data = test7sum, size = 1.5, alpha = 0.5, color = "steelblue4", fill = "steelblue4",
               aes(x = meta_adj)) +
  facet_grid(density ~ synchrony , scales = "free_y") + 
  xlab("date") + ylab("proportion") +
  theme(strip.text.x = element_text(size = 14),
        strip.text.y = element_text(size = 14)) 
plot6

## Original hatching and hatching of survivors
plot6b <- ggplot(test7sum, aes(hatch_adj)) + mytheme +
  # gray: original/imposed hatching synchrony
  geom_density(size = 1.5, alpha = 0.25, fill = "black", color = "gray39", linetype = "dashed") + 
  # blue: hatching dates of survivors
  geom_density(data = test7surv, size = 1.5, alpha = 0.5, color = "steelblue4", fill = "steelblue4",
               aes(x = hatch_adj)) +
  facet_grid(density ~ synchrony, scales = "free_y") + 
  xlab("date") + ylab("proportion") +
  theme(strip.text.x = element_text(size = 14),
        strip.text.y = element_text(size = 14))
plot6b 

## original hatching, survival hatching and metamorph
plot6c <- ggplot(test7sum, aes(hatch_adj)) + mytheme +
  # gray: original/imposed hatching synchrony
  geom_density(size = 1.5, alpha = 0.25, fill = "black", color = "gray39", linetype = "dashed") + 
  # blue: hatching dates of the ones that survived and metamorphed
  #geom_density(data = test7surv, size = 1.5, alpha = 0.5, color = "steelblue4", fill = "steelblue4",
  #              aes(x = hatch_adj)) +
  # red: the date of metamorphosis for survivors
  geom_density(data = test7sum, size = 1.5, alpha = 0.5, color = "tomato4", fill = "tomato4",
               aes(x = meta_adj + 5)) +
  facet_wrap(density ~ synchrony, scales = "free_y") +
  xlab("days after first individual") + ylab("proportion of individuals") +
  theme(strip.background = element_blank(),
        strip.text = element_blank(),
        axis.text.y = element_blank())
plot6c 

## Synchrony treatments - for methods in ppt
plot6x <- ggplot(test7sum, aes(hatch_tick, color = synchrony)) + mytheme +
  geom_density(adjust = 2, size = 3, alpha = 0.25) +
  xlab("hatch date") + ylab("proportion") +
  theme(legend.position = "none",
        axis.title = element_text(size = rel(1.25))) +
  scale_color_manual(values = c("black", "black", "black", "black"))
plot6x

## Single synchrony trts - for methods in ppt
plot6xa <- ggplot(subset(test7sum, sync == 7), aes(hatch_tick)) + mytheme +
  geom_density(adjust = 2, size = 2, alpha = 0.25) +
  xlab("hatch date") + ylab("proportion of individuals") +
  theme(legend.position = "none",
        axis.title = element_text(size = rel(1.25)))
plot6xa

###---7. Growth rates by hatch date---------------------------------
z <- subset(test7sum, subset = (rep == 3))  ## resource starts at 20, but ~50% survival even if they beat resource by 6 days
plot7 <- ggplot(z, aes(x = hatch_tick, y = growthrate)) + 
  geom_point(alpha = 0.65, size = 2, aes(color = as.factor(meta))) +
  stat_smooth(method = "lm", formula = y ~ poly(x, 2), se = T, size = 2, color = "gray39") +
  facet_grid(density ~ synchrony, scales = "free") + mytheme +
  theme(legend.position = "none",
        strip.text.x = element_text(size = 14),
        strip.text.y = element_text(size = 14)) +
  xlab("hatch date") + ylab("growth rate")
plot7

###---8. Growth rates variation-------------------------------------
plot8 <- ggplot(subset(test7sum, meta == 1), aes(x = growthrate, color = synchrony)) + mytheme +
  geom_density(size = 2) + 
  facet_grid(density ~ .) +
  xlab("growth rate") + ylab("proportion")
plot8

###---9. Probability of metamorphing-------------------------------- 
plot9 <- ggplot(test7sum, aes(x = hatch_tick, y = meta, color = as.factor(dens))) +
  geom_point(alpha = 0.25) + mytheme +
  stat_smooth(method = 'glm', method.args = 'binomial', size = 2, alpha = 0.5, se = F) +
  facet_wrap(~sync)
plot9                  


###--- All plots----------------------------------------------------
plot2 # linear growth by trt
plot3 # final size by hatch-tick, factored by trts
plot4 # surv prob by hatch-tick, factored by trt
plot5 # n_metamorphs, by trt
plot6 # density plots, synchrony through stages
plot7 # growth rates by hatch date
plot8 # variation in growth rates among individuals by trt
plot9 # surv prob by hatch-tick, colored by trt

#############################################################
###---------------------ANALYSIS--------------------------###
#############################################################

## Full data, testing additive and interactive effects on survival
m <- lmer(n_meta ~ dens * sync + (1 | rep), data = test8supersum)
coefs_m <- data.frame(coef(summary(m)))
coefs_m$p.val <- 2 * (1 - pnorm(abs(coefs_m$t.value)))
coefs_m

## Considering only medium density, effects of sync on survival
meddens <- subset(test8supersum, subset = (dens == 120))
m1 <- lmer(n_meta ~ sync + (1 | rep), data = meddens)
coefs_m1 <- data.frame(coef(summary(m1)))
coefs_m1$p.val <- 2 * (1 - pnorm(abs(coefs_m1$t.value)))
coefs_m1

