#CHECK IF MSA generation is required or not
if [ %msa_gen_max_iter.content == "0" ] ; then
        reformat_hhsuite.pl fas a3m %alignment.path query.a3m -M first
        mv query.a3m ../results/query.a3m
        addss.pl ../results/query.a3m
else
    #MSA generation required
    #MSA generation by HHblits
    hhblits -cpu 8 \
            -v 2 \
            -i %alignment.path \
            -d %UNIPROT  \
            -o ../results/msagen.hhblits \
            -oa3m ../results/query.a3m \
            -n %msa_gen_max_iter.content \
            -mact 0.35
    addss.pl ../results/query.a3m
fi

# Here assume that the query alignment exists

# prepare histograms
# Reformat query into fasta format ('full' alignment, i.e. 100 maximally diverse sequences, to limit amount of data to transfer)
hhfilter -i ../results/query.a3m \
         -o ../results/query.reduced.a3m \
         -diff 100

# max. 160 chars in description
reformat_hhsuite.pl a3m fas "$(readlink -f ../results/query.reduced.a3m)" query.fas -d 160 -uc
mv query.fas ../results/query.fas

# Reformat query into fasta format (reduced alignment)  (Careful: would need 32-bit version to execute on web server!!)
hhfilter -i ../results/query.a3m \
         -o ../results/query.reduced.a3m \
         -diff 50

reformat_hhsuite.pl -r a3m fas "$(readlink -f ../results/query.reduced.a3m)" query.reduced.fas -uc
mv query.reduced.fas ../results/query.reduced.fas

rm ../results/query.reduced.a3m



# build histogram

reformat.pl a3m \
            fas \
            "$(readlink -f  ../results/query.a3m)" \
            "$(readlink -f  ../results/query.full.fas)"


hhfilter -i ../results/query.reduced.fas \
         -o ../results/query.top.a3m \
         -id 90 \
         -qid 0 \
         -qsc 0 \
         -cov 0 \
         -diff 10


reformat_hhsuite.pl a3m fas  "$(readlink -f ../results/query.top.a3m)" query.repseq.fas -uc
mv query.repseq.fas ../results/query.repseq.fas

# creating alignment of query and subject input
if [  %hhpred_align.content == "true" ]
then
    cd ../results
    ffindex_from_fasta -s db_fas.ffdata db_fas.ffindex %alignment_two.path
    mpirun -np %THREADS ffindex_apply_mpi db_fas.ffdata db_fas.ffindex -i db_a3m_wo_ss.ffindex -d db_a3m_wo_ss.ffdata -- hhblits -d %UNIPROT -i stdin -oa3m stdout -n %msa_gen_max_iter.content -cpu 1 -v 0
    mpirun -np %THREADS ffindex_apply_mpi db_a3m_wo_ss.ffdata db_a3m_wo_ss.ffindex -i db_a3m.ffindex -d db_a3m.ffdata -- addss.pl -v 0 stdin stdout
    mpirun -np %THREADS ffindex_apply_mpi db_a3m.ffdata db_a3m.ffindex -i db_hhm.ffindex -d db_hhm.ffdata -- hhmake -i stdin -o stdout -v 0
    OMP_NUM_THREADS=%THREADS cstranslate -A ${HHLIB}/data/cs219.lib -D ${HHLIB}/data/context_data.lib -x 0.3 -c 4 -f -i db_a3m -o db_cs219 -I a3m -b
    ffindex_build -as db_cs219.ffdata db_cs219.ffindex
    DBJOINED="-d ../results/db"
    cd ../0
else
    #splitting input databases into array and completing with -d
        if [ %hhsuite.content != "false" ]
    then
        DBS=$(echo "%hhsuitedb.content" | tr " " "\n")
        DBJOINED=`printf -- '-d %HHSUITE/%s ' ${DBS[@]}`
    fi
    if [ %proteomes.content != "false" ]
    then
        PROTEOMES=$(echo "%proteomes.content" | tr " " "\n")
        DBJOINED+=`printf -- '-d %HHSUITE/%s ' ${PROTEOMES[@]}`
    fi
fi

# Perform HHsearch # TODO Include more parameters
hhsearch -cpu %THREADS \
         -i ../results/query.a3m \
         ${DBJOINED} \
         -o ../results/hhsearch.hhr \
         -p %pmin.content \
         -P %pmin.content \
         -Z %max_lines.content \
         -%alignmode.content \
         -z 1 \
         -b 1 \
         -B %max_lines.content \
         -ssm %ss_scoring.content \
         -seq 1 \
         -aliw %aliwidth.content \
         -dbstrlen 10000 \
         -cs ${HHLIB}/data/context_data.lib \
         -atab $(readlink -f ../results/hhsearch.start.tab) \
         %macmode.content \
         -mact %macthreshold.content


JOBID=%jobid.content

# Generate input files for hhviz
cp ../results/hhsearch.hhr ../results/${JOBID}.hhr

hhviz.pl ${JOBID} ../results/ ../results/  &> /dev/null

profile_logos.pl ${JOBID} ../results/ ../results/

tar xfvz ../results/${JOBID}.tar.gz -C ../results/

tenrep.rb -i ../results/query.repseq.fas -h ../results/${JOBID}.hhr -p 40 -o ../results/query.tenrep_file

cp ../results/query.tenrep_file ../results/query.tenrep_file_backup

parse_jalview.rb -i ../results/query.tenrep_file -o ../results/query.tenrep_file


# Reformat tenrep file such that we can display it in the full alignment section
reformat.pl fas \
            clu \
            "$(readlink -f ../results/query.tenrep_file)" \
            "$(readlink -f ../results/alignment.clustalw_aln)"



# Generate Hitlist in JSON for hhrfile
 
hhr2json.py "$(readlink -f ../results/hhsearch.hhr)" > ../results/hhr.json

# Generate Query in JSON
fasta2json.py %alignment.path ../results/query.json
