nextflow.enable.dsl=2

process sample_seq {
    tag "$key"
    label 'concensus_processing'

    input:
        tuple val(key), path(fasta), path(samples)
    output:
        tuple val(key), path("sampled.fa")

"""
 rg -A1 -f <(awk '{print \$1}' $samples) $fasta | rg -v "^--\$" > sampled.fa
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
    publishDir "${params.outDir}/alignments", mode:"copy", overwrite:"true", saveAs:{"${key}.fa"}
    
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
        fa_ch
        sample_ch
        ref_ch
        masked_ch
    main:
        fa_ch \
        | join(sample_ch) \
        | sample_seq \
        | join(ref_ch) \
        | minimap2 \
        | sam_to_fasta \
        | join(masked_ch) \
        | mask 
    emit:
        mask.out

}