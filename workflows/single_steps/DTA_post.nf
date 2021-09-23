nextflow.enable.dsl=2

def get_key_logs(path){
    name=path.name.take(path.name.lastIndexOf('.'));
    name.substring(name.indexOf("_")+1)
}

def get_key_trees(path){
    name=path.name.take(path.name.lastIndexOf('.'));
    name.substring(name.indexOf("_")+1)
}


        

process combine_logs{
    tag "${key}"
    publishDir "${params.outDir}/DTA/combined_logs",  overwrite:"true", saveAs:{"${key}.b${burnin/1_000_000}M.s${resample/1_000}K.log"}
        errorStrategy 'finish'
    input:
        tuple val(key), path(logs), val(burnin) ,val(resample)
    output:
        tuple val(key), path("combined.log")

"""
logcombiner  ${(burnin>0? "-burnin ${burnin}": "")} \
            ${(resample>1?"-resample ${resample}":"")} \
             ${logs}  combined.log
"""
}
process combine_trees {
    tag "${key}"
        publishDir "${params.outDir}/DTA/combined_trees",  overwrite:"true", saveAs:{"${key}.combined.trees"}
        errorStrategy 'finish'
    input:
        tuple val(key), path(trees), val(burnin),val(resample)
    output:
        tuple val(key), path("combined.trees")

"""
logcombiner -trees ${(burnin>0? "-burnin ${burnin}": "")} \
            ${(resample>1? "-resample ${resample}":"")} \
             ${trees} combined.trees
"""
}

process mcc{
    tag"${key}"
    publishDir "${params.outDir}/DTA/mcc",  overwrite:"true", saveAs:{"${key}.mcc.tree"}
        errorStrategy 'finish'

   input:
        tuple val(key),path(trees)
    output:
        tuple val(key),path("mcc.tree")
"""
treeannotator  $trees mcc.tree
"""
}

process transmission_lineage{
    tag "${key}"
publishDir "${params.outDir}/DTA/transmission", pattern: "*tsv", mode:"copy", saveAs:{"${key}.TL.tsv"}
    input:
        tuple val(key),path(tree)
    output:
        tuple val(key),path("tl.tsv")

"""
RUST_LOG=info fertree transmission-lineages -i $tree -k location --to $params.location --nexus >tl.tsv
"""
}


workflow DTA_post_processing{
    take: log_ch
        tree_ch
    main:
        log_ch | combine_logs

        tree_ch | combine_trees 

        // | mcc

// transmission_lineage(combine_trees.out)

}

