nextflow.enable.dsl=2

def get_seeds(seed,n){
    def random= new Random(seed)

    beast_seeds=[];
    for(int i=0;i<n;i++){
        beast_seeds.add(random.nextInt() & Integer.MAX_VALUE)
    }
    return beast_seeds
}
process preliminary_beast_process{
    tag "${key}-${seed}"
    label 'beast'
    publishDir "${params.outDir}/preliminary/${key}", mode:"copy", overwrite:"true"
    input:
        tuple val(key), path(xml_file), val(seed)
    output:
        tuple val(key), path("*log"), emit: logs
        tuple val(key), path("*trees"), emit:trees
        path("*ops")
        path("*out")
        path("*chkpt") optional true
"""
beast  ${(params.save_every>0? "-save_every ${params.save_every} -save_state ${seed}_${key}.chkpt":'')}  -prefix ${seed}_ -seed ${seed}  ${xml_file} > ${key}-${seed}.out
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
        tuple val(key), path("*4500*log"), emit: logs
        tuple val(key), path("*4500*trees"), emit:trees
        path("*ops")
        path("*out")
        path("*log")
        path("*chkpt") optional true
"""
beast  ${(params.save_every>0? "-save_every ${params.save_every} -save_state ${seed}_${key}.chkpt":'')} -beagle_scaling always -prefix ${seed}_ -seed ${seed}  ${xml_file} > ${key}-${seed}.out
"""
}

//TODO add n to run options
workflow preliminary_beast{
take:
    xml_seeds_ch
    main:
    preliminary_beast_process(xml_seeds_ch)

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

