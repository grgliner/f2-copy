## compare msmsc gene flow estimates to the between population
## f2 density estimates.

code.dir <- "~/f2_age/code/"
source("~/f2_age/code/libs/include.R")

## sim.type="ancient_split_long_migration" 
sim.type="ancient_split_migration" 
## sim.type="ancient_split" 
## sim.type="third_party" 
## sim.type="ancient_split_migration_growth" 
## sim.type="ancient_split_migration_bottleneck" 
## sim.type="ancient_split_migration_200" 

chr="20"

load(paste0("~/f2_age/simulations/", sim.type, "/chr", chr, "/results/ll_and_density_environment.Rdata"))
dyn.load("~/f2_age/code/libs/inference.so")
msmc <- read.table(paste0("~/f2_age/simulations/", sim.type, "/chr", chr, "/results/msmc_results_all.final.txt"), header=T, as.is=T)

within <- (matched$ID1<51 & matched$ID2<51)|(matched$ID1>50 & matched$ID2>50)
if(grepl("200", sim.type)){within <- (matched$ID1<101 & matched$ID2<101)|(matched$ID1>100 & matched$ID2>100)}
between <- !within

## alpha.w <- round(0.05*sum(within))
## alpha.b <- round(0.05*sum(between))
## alpha <- round(0.05*NROW(matched))
## ## d.b <- estimate.t.density.mcmc(0*matched$map.len[between,] ,0*matched$f2[between,], Ne, p.fun, verbose=FALSE, logt.grid=logt.grid, prior=norm.2.p, alpha=alpha,error.params=NA, n.sims=10000, thin=100, ll.mat=ll.mats[[6]][between,])

t.hats<-MLE.from.haps(matched[between,], Ne, S.params=S.params[between,], error.params=error.params, verbose=TRUE)
t.hat.dens <- density(log10(t.hats))

par(mar=c(5.1,4.1,2.1,4.1))
plot(msmc$left_time_boundary/1.2e-8, 2*msmc$lambda_01/(msmc$lambda_00+msmc$lambda_11), type="s", log="x", ylim=c(0,1), xlim=c(100,10000), bty="n", xlab="Generations", ylab="MSMC gene flow estimate", col="#E41A1C", yaxt="n", main="")
axis(2, col="#E41A1C")
scale <- max(t.hat.dens$y)
lines(10^t.hat.dens$x, t.hat.dens$y/scale, col="#377EBA")
abline(v=median(t.hats), col="#377EBA", lty=2)
axis(4, col="#377EBA", labels=FALSE)
mtext(expression(f[2]~age~density), 4, line=2)
abline(v=1120, lty=3)
if(grepl("migration", sim.type)){abline(v=560, lty=3)}

## scale2 <- max(d.b(logt.grid))
## lines(logt.grid, d.b(logt.grid)/scale2, col="#377EBA", lty=2)

## par(mfrow=c(2,2))
## hist(log10(matched$Age[between]), breaks=100, xlim=c(0,5))
## hist(log10(t.hats[between]), breaks=100, xlim=c(0,5))
## hist(log10(matched$Age[within]), breaks=100, xlim=c(0,5))
## hist(log10(t.hats[within]), breaks=100, xlim=c(0,5))

