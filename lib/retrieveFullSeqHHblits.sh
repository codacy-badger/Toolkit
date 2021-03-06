#!/bin/bash
# Set environment
if [ "$HOSTNAME" = "olt" ]
  then
    source /ebio/abt1_share/toolkit_support1/code/bioprogs/env/environment.sh

elif [ "$HOSTNAME" = "rye" ]
  then
    source /cluster/toolkit/production/bioprogs/env/environment_rye.sh
  fi

    HHBLITS=${DATABASES}/hhblits/
    DB=${STANDARD}/uniprot_trembl

    #separate accessions in string by whitespace
    ACCESSIONS=$(echo $accessionsStr | tr " " "\n")

    # write accessions to be retrieved in file
    printf "${ACCESSIONS[@]}" > results/${filename}_accessionsToRetrieve

    #retrieve full length sequences
    seq_retrieve.pl -i results/${filename}_accessionsToRetrieve \
                    -o results/${filename}.fa \
                    -d ${DB} \
                    -unique 1 > results/${filename}_unretrievabl
