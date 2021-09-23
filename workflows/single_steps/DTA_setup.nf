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
    publishDir "${params.outDir}/preliminary/combined_logs", mode:"copy", overwrite:"true", saveAs:{"${key}.b${burnin/1_000_000}M.s${resample/1_000}K.log"}
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
        errorStrategy 'finish'
    publishDir "${params.outDir}/preliminary/combined_trees", mode:"copy", overwrite:"true", saveAs:{"${key}.b${burnin/1_000_000}M.s${resample/1_000}K.trees"}

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

process make_taxa_nexus{
    tag "${key}"
        errorStrategy 'finish'
    input:
        tuple val(key), path(trees) 
    output:
        tuple val(key), path("taxa.nexus")
shell:
'''
cutoff=$(grep -ni "begin trees" !{trees}  | cut -f1 -d:)
awk  -v cutoff="$cutoff" 'NR<cutoff {print}' !{trees}  >taxa.nexus
'''

}

process beastgen{
    tag "${key}"
    stageInMode "copy"
    publishDir "${params.outDir}/DTA/xml", pattern: "*xml",  saveAs:{"${key}.DTA.xml"}
    publishDir "${params.outDir}/DTA/xml", pattern: "*trees",  saveAs:{"${key}.emp.trees"}
    input: 
        tuple val(key),path(trees),path(taxa_nexus),path(traits),path(xml_template),val(dBeastgenOptions)
    output:
        tuple val(key),path("dta.xml"),path(trees)

"""
cp $xml_template ./local_template;
beastgen -date_order -1 -date_prefix "|" -date_precision \
    -D "outputFileStem=${key},empTreeFile=${trees.name},${dBeastgenOptions}" \
    -traits $traits \
    local_template \
    $taxa_nexus \
    dta.xml
"""
}

workflow combine_runs {
    take:
        log_ch
        tree_ch
    main:
    log_ch | combine_logs

    tree_ch | combine_trees
    emit:
        combine_trees.out
}


workflow setupDTA{
    take:
        tree_ch
        beastgen_ch
    main:
    tree_ch \
        | make_taxa_nexus
        
   tree_ch.join(make_taxa_nexus.out)
        .join(beastgen_ch) \
        | beastgen

    emit:
        beastgen.out
}

// workflow {
// def jsonSlurper = new groovy.json.JsonSlurper()
// input=jsonSlurper.parse(new File(params.i))

// trees = input.runs.collect{
//     it->
//     files_ch =  Channel.fromPath(it.trees.files)
//   return files_ch
//             .collect()
//             .map(f->[it.key,f,it.trees.burnin,it.trees.resample, it.trees.outDir])  
// }

// tree_ch = trees[0];
// for(int i = 1; i<trees.size();i++){
//     tree_ch=tree_ch.mix(trees[i])
// }
// logs = input.runs.collect{
//     it->
//     files_ch =  Channel.fromPath(it.logs.files)
//   return files_ch
//             .collect()
//             .map(f->[it.key,f,it.logs.burnin,it.logs.resample, it.logs.outDir])  
// }

// log_ch = logs[0];
// for(int i = 1; i<logs.size();i++){
//     log_ch=log_ch.mix(logs[i])
// }

// beastgens = input.runs.collect{
//     it->
//     files_ch =  Channel.fromPath(it.beastgen.template)
    
//   return files_ch.mix(Channel.fromPath(it.beastgen.tsv)).collect()
//             .flatMap(f->[[it.key,f[0]], [it.key,f[1]], [it.key, it.beastgen.outDir]])
  
// }

// beastgen_ch = beastgens[0];
// for(int i = 1; i<beastgens.size();i++){
//     beastgen_ch=beastgen_ch.mix(beastgens[i])
// }

// setupDTA(log_ch,tree_ch,beastgen_ch)

// }

