nextflow.enable.dsl=2


//input format is 
    // run:{key:key,ml:tree}
// This takes a tree runs treetime and ouputs a nexus file

process tree_time{
    tag "$key"
    stageInMode 'copy'
    publishDir "${params.outDir}/input_trees" , pattern: "outliers.txt", mode:"copy", saveAs: {"${key}.outliers.txt"}
    input:
        tuple val(key), path(tree)
    output:
        tuple val(key), path("divergence_tree.nexus"),path("timetree.nexus"), path("outliers.txt")
    script:
if(params.clock_rate==null)
"""
gotree reformat nexus -i $tree -o timetree.nexus
gotree reformat nexus -i $tree -o divergence_tree.nexus
touch outliers.txt

"""
else
"""
#make date file
echo -e 'name\tdate'>input_dates.tsv
fertree extract taxa -i $tree | \
awk '{n=split(\$1,a,"\\|");printf "%s\\t%s\\n",\$1,a[n]}'>>input_dates.tsv

treetime --tree $tree \
    --dates input_dates.tsv \
    --keep-root \
    --keep-polytomies \
    --sequence-length $params.sequence_length \
    --clock-rate ${params.clock_rate} \
    --clock-filter $params.clock_filter \
    --outdir ./

awk '\$3=="--"{print \$1}' dates.tsv > outliers.txt

"""

}

process clean_tree{
    tag "$key"
    input:
          tuple val(key), path(divergence_tree),path(time_tree), path(outliers)
    output:
        tuple val(key), path("nocomments_divergence_tree.tree") ,path("nocomments_time_tree.tree") , path(outliers)
    shell:
        template 'clean_tree.sh'
}

process refine {
    tag "$key"
    input:
        tuple val(key), path(ml_tree),path(time_tree), path(outliers)
    output:
        tuple val(key), path("refined_divergence_tree.tree"),path("refined_time_tree.tree")
    """
        gotree prune -f $outliers -i $ml_tree > refined_divergence_tree.tree
        gotree prune -f $outliers -i $time_tree > refined_time_tree.tree
    """

}

process resolve {
    tag "$key"
    input:
        tuple val(key),path(ml_tree),path(time_tree)
    output:
        tuple val(key),path(ml_tree),path("resolved.nw")
"""
RUST_LOG=info fertree resolve evenly -i $time_tree > resolved.nw 2>${key}.resolve.log
"""
}

process cat {
    tag "$key"
    input:
        tuple val(key), path(ml_tree), path(time_tree)
    output:
        tuple val(key), path('combined.nw')

"""
cat $ml_tree>combined.nw
cat $time_tree >> combined.nw
"""
}

process to_nexus{
    tag "$key"
    publishDir "${params.outDir}/input_trees" , pattern: "*nexus", mode:"copy", saveAs: {it.replaceAll("tree",key)}
    input:
        tuple val(key),path(tree)
    output:
        tuple val(key), path('tree.nexus')

"""
gotree reformat nexus -i $tree >tree.nexus
"""
}



workflow treetime{
take:trees
main:
	trees| tree_time \
    | clean_tree \
    | refine \
    | resolve \
    | cat \
    | to_nexus 
          
     emit:
     	to_nexus.out
     }
