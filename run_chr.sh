#!/bin/bash -vx

#The same as simulations/run_chr.sh except it uses fastsimcoal2 instead of macs. 
# Scenarios are defined by parameter files in this directory instead of cmd line
# args, named sim_type.par. Note that the parameters you define here have to match
# up with the ones in the file (this is really designed for macs). 

##############################################################################################################
# Script arguments
CHR=$1
N=$2 #how many haplotypes
n=$3 #how many sites
N=100
n=1000
##############################################################################################################

# Edit simulation parameters here. 

# where is fastsimcoal2?
FSC_DIR=/tigress/BEE/projects/dfcp/age/bin/fsc_linux64/
# Where do you want the simulations to go?
SIMS_DIR=/tigress/BEE/projects/dfcp/age/simulations/sim_${N}_${n}
# Where is the code - this point to the directory you downloaded from github
CODE_DIR=/tigress/genna/f2

# Parameters: number of hapotypes, Ne, estimated doubleton power, mutation rate 
# These need to match up with what's in the parameter file. We could fix this. 
nhp1=50
nhp2=50
nhp=$N
ne=12000
dbp=0.66
mu=0.000000012
nbp=$n

##############################################################################################################

# Where is the recombination map, in impute format?
# HM2_MAP=~/hm2_recombination_map/genetic_map_GRCh37_chr${CHR}.txt.gz
# For now this just handles constant maps at 1cm/Mb
HM2_MAP=/tigress/BEE/projects/dfcp/age/simulations/phaseme_input/recombination_genetic_maps/1kg_map/genetic_map_b36/genetic_map_chr1_b36.txt.gz 

# Setup directories
WD=${SIMS_DIR}/sim_simulated
TH=${SIMS_DIR}/haplotypes
RD=${SIMS_DIR}/results
MD=${SIMS_DIR}/map
CD=${CODE_DIR}

for dir in ${WD} ${TH}/by_sample ${RD} ${MD}
do
    mkdir -p ${dir}
done

# redirect output to logfile                    

LOG=${RD}/log.txt
# exec > ${LOG} 2>&1

# # compound params
# theta=`echo "4*$ne*$mu" | bc`
# rho=`echo "4*$ne*0.00000001" | bc`

# 1) convert hms map to macs format
#R --vanilla --slave --args ${HM2_MAP} ${MD}/map.txt ${MD}/cut.map.txt < ${CD}/scripts/convert_HM_maps_to_macs_format.R

# 2) Simulate using fastsimcoal
module load python/2.7 
cd $SIMS_DIR
python /tigress/BEE/projects/dfcp/age/simulations/pm_sim1_test/GeneratePARfromMap.py --recombination_map ${HM2_MAP} --scale 10 --ss ${N} --numvariants ${n}

sh sim_simulated.sh

#run the dfcp
#/usr/lib/jvm/jre-1.8.0-openjdk.x86_64/bin/java -jar /tigress/BEE/projects/dfcp/age/bin/phaseme.jar -varNexusFile sim_simulated/sim_simulated_1_true_trees.trees -varArpFile sim_simulated/sim_simulated_1_1.arp -varDate true -trajectories dfcp_output/trajectories.txt haps.txt  dfcp_output/hcg.txt output -genMapFilename sim_simulated.map -outfile outfile.txt

# 3)Parse the macs output to get trees and genotypes
gzip -f ${WD}/sim_simulated_1_true_trees.trees
gzip -f ${WD}/sim_simulated_1_1.arp

# extract trees and cut out the inital first brackets so that we can use the biopython parser. 
zgrep -o "[(].*[;]" ${WD}/sim_simulated_1_true_trees.trees.gz | grep -v "Laurent Excoffier" | gzip -c > ${WD}/trees.newick.txt.gz
# also store tract lengths - use these to recover positions. 
gunzip -c  ${WD}/sim_simulated_1_true_trees.trees.gz | cut -f2 -d " " | cut -f6 -d "_" | grep "[0-9]" > ${WD}/trees.starts.txt
echo $nbp >> ${WD}/trees.starts.txt
awk '{b=a;a=$1}b!=""{print $1-b}' ${WD}/trees.starts.txt > ${WD}/trees.lengths.txt
rm ${WD}/trees.starts.txt
gzip ${WD}/trees.lengths.txt

# Get genotypes and positions. 
#zgrep "^1_" ${WD}/sim_simulated_1_1.arp.gz | cut -f3 | sed "s/[2-9]/1/g" | less | gzip -c > ${WD}/genotypes.txt.gz
gzip -c ${SIMS_DIR}/haps.txt  > ${WD}/genotypes.txt.gz  
rm  ${SIMS_DIR}/haps.txt
zgrep -A1 "polymorphic positions"  ${WD}/sim_simulated_1_1.arp.gz | tail -n1 |  sed "s/[#,]//g" > ${WD}/tmp.pos
R --slave --args ${WD}/tmp.pos ${nbp} ${WD}/tmp2.pos < ${CD}/simulations2/convert_pos.R
gzip -c ${WD}/tmp2.pos > ${WD}/snps.pos.txt.gz
rm ${WD}/tmp.pos ${WD}/tmp2.pos

# Parse the genotype data into the right format, by haplotypes etc... 
python ${CD}/scripts/macs_genotype_to_hap_files.py -g ${WD}/genotypes.txt.gz \
 -p ${WD}/snps.pos.txt.gz -l ${nbp} -o ${TH}

# 4) Get the real haplotyes
python ${CD}/scripts/find_real_nns.py -t ${WD}/trees.newick.txt.gz  \
    -l ${WD}/trees.lengths.txt.gz -o ${TH}/NN_haplotypes.txt.gz -r 1 -f1 -e 1.0 -v1

# 5) extract f1 and f2 variants. 
python ${CD}/scripts/calculate_fn_sites.py -h ${TH}/haps.f1.gz -o ${TH}/pos.idx.f1.gz -n 1 -v 1 > ${TH}/f1.pos.tmp.log
python ${CD}/scripts/calculate_fn_sites.py -h ${TH}/haps.f2.gz -o ${TH}/pos.idx.f2.gz -n 2 > ${TH}/f2.pos.tmp.log
python ${CD}/scripts/haps_to_gt_bysample.py -h ${TH}/haps.gz  -o ${TH}/by_sample/ -s ${TH}/samples.txt

# 6) Estimate haplotypes from f2 variants
R --vanilla --quiet --slave --args ${CD} ${TH} ${RD}/f2_haplotypes.txt ${SIMS_DIR}/sim_simulated.map 0 < ${CD}/scripts/haplotypes_from_f2.R
gzip -f ${RD}/f2_haplotypes.txt 

# 7) Compare haplotpyes and compute power, then compare estimates of time. 
R --vanilla --quiet --slave --args ${CD} ${TH} ${RD} ${ne} ${dbp} ${SIMS_DIR}/sim_simulated.map ${nhp} fastsimcoal < ${CD}/scripts/compare_haplotypes.R
gzip -f ${RD}/matched_haps.txt
R --vanilla --quiet --slave --args ${CD} ${TH} ${RD} ${TH}/samples.txt ${SIMS_DIR}/sim_simulated.map 100 ${mu} two.way ${nbp} < ${CD}/scripts/estimate_error_parameters.R
R --vanilla --quiet --slave --args ${CD} ${RD} ${ne} ${nhp} ${mu} 6 60 < ${CD}/scripts/compare_estimates.R
