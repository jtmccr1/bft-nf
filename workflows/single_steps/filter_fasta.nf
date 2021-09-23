nextflow.enable.dsl=2

process sample_meta{
    tag "$key"
    publishDir "${params.outDir}/filter" , pattern: "*tsv", saveAs: {it.replaceAll("meta",key)}
    input:
        tuple val(key), path(metadata),val(n),val(wieghts)
    output:
        path("meta.tsv")
        tuple val(key), path("names.txt"), emit : seqNames
"""
sampler -i $metadata -n $n -w $wieghts >meta.tsv;

cut -f1 meta.tsv | sed 1,1d > names.txt
"""
}

process process_fa {
    tag "$key"
    publishDir "${params.outDir}/filter" , pattern: "*fa", saveAs: {it.replaceAll("fasta",key)}

    input:
        tuple val(key), path(fasta), path(seqNames)
    output:
        tuple val(key), path("fasta.fa")
"""
get_fasta_from_IDs.py $fasta $seqNames >fasta.fa
"""
}


workflow filter_fasta {
    take:
        metadata_ch
        fa_ch

    main:
    
    sample_meta(metadata_ch)

    fa_ch.join(sample_meta.out.seqNames) \
    | process_fa 

    emit:
    process_fa.out
}