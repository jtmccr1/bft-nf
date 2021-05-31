nextflow.enable.dsl=2


process iqtree2{
    tag "$key"
    label 'tree_building'
    input:
        tuple val(key), path(alignment)
    output:
        tuple val(key), path("tree.treefile")
"""
iqtree2 -s $alignment $params.iqtree2_settings --prefix tree
"""
}


process reroot {
    tag "$key"
    
    input: 
       tuple val(key), path(tree), val(outgroup),val(prune)
    output:
       tuple val(key), path("rooted.nw")
    script:
        if(outgroup==null)
        """
        cp $tree rooted.nwk
        """
        if (prune)
            """ 
            gotree reroot outgroup -i $tree $outgroup --remove-outgroup | gotree unroot > rooted.nw
            """
        else
            """
            gotree reroot outgroup -i $tree $outgroup | gotree unroot> rooted.nw
            """
}

process rename {
    tag "$key"
    publishDir "${params.outDir}/ML_tree" , pattern: "*nw", mode:"copy", saveAs: {"${key}.nw"}
    input:
    tuple val(key), path(tree), path(nameMap)
    output:
        tuple val(key), path("renamed.nw")
"""
gotree rename -i $tree -m $nameMap -o renamed.nw
"""

}

process collapse {
    tag "$key"
    input:
       tuple val(key),path(tree)
    output:
       tuple val(key),  path("collapsed.nw")
"""
gotree collapse length -l $params.min_bl -i $tree -o collapsed.nw
""" 
}


workflow ML_tree {
	take:
	 alignment_ch
     outgroup_ch
	 nameMap_ch
	
	main:
	
    iqtree2(alignment_ch) \
    | join(outgroup_ch) \
    | reroot \
    | collapse \
    | join(nameMap_ch) \
    | rename 

    emit: 
    	rename.out
}
