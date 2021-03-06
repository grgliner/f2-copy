## find the haplotypes using the f2 variants.
## args should be 1) the directory with the haplotypes in (f1, f2 and by sample) 2) The output file and 3) The map file/rate
## 4) Singleton power, 5) mutation rate

library(dplyr)

args <- commandArgs(TRUE)

n.cores <- 1
f2.filename <- "/pos.idx.f2.gz"
if((length(args) %in% c(5,6,7))){
  code.dir <- args[1]
  hap.root <- args[2]
  out.file <- args[3]
  map.file <- args[4]
  verbose <- as.numeric(args[5])
  if(length(args)==6){
      n.cores <- as.numeric(args[6])
  }
    if(length(args)==7){
      f2.filename <- args[7]
  }

} else{
  stop("Need to specify 5 or 6 or 7 arguments")
}

source(paste(code.dir, "/libs/include.R", sep=""))

f1.file <- paste(hap.root, "/pos.idx.f1.gz", sep="")
f2.file <- paste(hap.root, f2.filename, sep="")

pos.file <- paste(hap.root, "/by_sample/pos.gz", sep="")
by.sample.gt.root <- paste(hap.root, "/by_sample", sep="")
samples <- scan(paste(hap.root, "/samples.txt", sep=""), quiet=TRUE, what="")
sim.pop.map <- rep("ALL", length(samples))
names(sim.pop.map) <- samples

if(n.cores==1){
    haps <- find.haplotypes.from.f2(f1.file, f2.file, pos.file, by.sample.gt.root, sim.pop.map, map.file, verbose=verbose)
}else{
    require(parallel)
    pos <- scan(pos.file, quiet=TRUE)
    pos <- range(pos)+c(-1e6, 1e6)
    breaks <- seq(pos[1], pos[2], length.out=n.cores+1)
    poss <- list()
    for(i in 1:n.cores){
        poss[[i]] <- breaks[c(i,i+1)]
    }
    haps <- mclapply(poss, find.haplotypes.from.f2.vector, mc.cores=n.cores, f1.file=f1.file, f2.file=f2.file, pos.file=pos.file, by.sample.gt.root=by.sample.gt.root, pop.map=sim.pop.map,  map.file=map.file, verbose=FALSE)
    haps <- do.call(rbind, haps)
}

## Just remove the ones with zero length.
cat(paste0("Removed ", sum(haps$map.len>0), " haplotypes with length 0\n"))
haps <- haps[haps$map.len>0,]

write.table(haps, out.file, row.names=FALSE, col.names=TRUE, quote=FALSE)
