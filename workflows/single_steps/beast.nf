nextflow.enable.dsl=2


process preliminary_beast_process{
    tag "${key}-${seed}"
    label 'beast'
    publishDir "${params.outDir}/preliminary/${key}", mode:"copy", overwrite:"true"
    input:
        tuple val(key), path(xml_file), val(seed)
    output:
        tuple val(key), path("${seed}_${key}.log"), emit: logs
        tuple val(key), path("${seed}_${key}.trees"), emit:trees
        path("${seed}_${key}.ops")
        path("${key}-${seed}.out")
        path("${seed}_${key}.chkpt") 
"""
beast   -save_every ${params.save_every} -save_state ${seed}_${key}.chkpt  -prefix ${seed}_ -seed ${seed}  ${xml_file} > ${key}-${seed}.out
"""
}
//TODO better passing of logs and trees to output
process DTA_beast_process{
    tag "${key}-${seed}"
    label 'beast'
    publishDir "${params.outDir}/DTA/${key}", mode:"copy", overwrite:"true"
    input:
        tuple val(key), path(xml_file), path(trees),val(seed)
    output:
        tuple val(key), path("${seed}_${key}.log"), emit: logs
        tuple val(key), path("${seed}_${key}.trees"), emit:trees
        path("${seed}_${key}.ops")
        path("${key}-${seed}.out")
        path("${seed}_${key}.full.log")
        path("${seed}_${key}.location.rates.log")
        path("${seed}_${key}.location.history.trees")
        path("${seed}_${key}.complete.history.log")

"""
beast   -beagle_scaling always -prefix ${seed}_ -seed ${seed}  ${xml_file} > ${key}-${seed}.out
"""
}

//TODO add n to run options
workflow preliminary_beast{
take:
    xml_seeds_ch
    main:
    preliminary_beast_process(xml_seeds_ch)
    emit:
        logs = preliminary_beast_process.out.logs 
        trees = preliminary_beast_process.out.trees 

}

workflow DTA_beast{
    take:
    xmls_tree_seeds_ch
    main:
    DTA_beast_process(xmls_tree_seeds_ch)
    emit:
        logs = DTA_beast_process.out.logs 
        trees = DTA_beast_process.out.trees 
}

