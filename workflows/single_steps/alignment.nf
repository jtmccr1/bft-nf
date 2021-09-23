nextflow.enable.dsl=2

process sample_metadata {
    tag "$key"
    label 'concensus_processing'

    input:
        tuple val(key), path(metadata),val(n), val(sample_options)
    output:
        tuple val(key), path("sampled.tsv")

"""
 sampler -i $metadata -n $n ${sample_options} > sampled.tsv
"""

}


process sample_seq {
    tag "$key"
    label 'concensus_processing'

    input:
        tuple val(key),  path(samples), path(fasta),
    output:
        tuple val(key), path("sampled.fa")

"""
 python ${workflow_dir}
"""
}

process minimap2{
    tag "$key"
    label 'concensus_processing'
    input:
        tuple val(key), path(fasta),path(reference)
    output:
        tuple val(key), path("sam.sam"), path(reference)
"""
 minimap2 -t 3 -a -x asm5 $reference $fasta > sam.sam
"""
}

process sam_to_fasta{
    tag "$key"
    label 'concensus_processing'
    input:
        tuple val(key), path(sam), path(reference)
    output:
        tuple val(key), path("aligned.fa")
"""
gofasta sam toMultiAlign -t 3 --reference $reference -s $sam --pad > aligned.fa
"""
}

process mask{
    tag "$key"
    label 'concensus_processing'
    publishDir "${params.outDir}/alignments", overwrite:"true", saveAs:{"${key}.fa"}
    
    input:
        tuple val(key), path(fasta), val(masked_sites)
    output:
        tuple val(key), path("masked.fa")
"""
goalign mask -t 3 -s $masked_sites -l 1 -i $fasta -o masked.fa
"""
}

workflow align_sequences {
    take:
        sample_ch
        fa_ch
        ref_ch
        masked_ch
    main:
    sample_ch \
        | join(fa_ch) \
        | sample_seq \
        | join(ref_ch) \
        | minimap2 \
        | sam_to_fasta \
        | join(masked_ch) \
        | mask 
    emit:
        mask.out

}