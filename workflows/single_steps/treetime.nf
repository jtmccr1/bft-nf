nextflow.enable.dsl=2


//input format is 
    // run:{key:key,ml:tree}
// This takes a tree runs treetime and ouputs a nexus file

process tree_time{
    tag "$key"
    stageInMode "copy"
    input:
        tuple val(key), path(tree)
    output:
        tuple val(key), path("timetree.nexus"), emit:timetree
        tuple val(key),path(tree), emit:og
"""
#make date file
echo -e 'name\tdate'>dates.tsv
fertree extract taxa -i $tree | \
awk '{n=split(\$1,a,"\\|");printf "%s\\t%s\\n",\$1,a[n]}'>>dates.tsv

treetime --tree $tree \
    --dates dates.tsv \
    --keep-root \
    --keep-polytomies \
    --sequence-length $params.sequence_length \
    --clock-rate $params.clock_rate \
    --clock-filter 0 \
    --outdir ./
"""

}

process clean_tree{
    tag "$key"
    input:
          tuple val(key), path(tree)
    output:
        tuple val(key), path("nocomments.tree")
    shell:
        template 'clean_tree.sh'
}

process resolve {
    tag "$key"
    input:
        tuple val(key),path(tree)
    output:
        tuple val(key),path("resolved.nw")
"""
RUST_LOG=info fertree resolve evenly -i $tree > resolved.nw 2>${key}.resolve.log
"""
}

process cat {
    tag "$key"
    input:
        tuple val(key), path(tree1), path(tree2)
    output:
        tuple val(key), path('combined.nw')

"""
cat $tree1>combined.nw
cat $tree2 >> combined.nw
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
	trees| tree_time 

    tree_time.out.timetree \
    | clean_tree \
    | resolve 

    resolve.out.mix(tree_time.out.og)
        .groupTuple(size:2,sort:{!it.name =="resolved.nw"})
        .map(t->[t[0],t[1][0],t[1][1]]) \
     | cat \
     | to_nexus 
     
     
     emit:
     	to_nexus.out
     }
