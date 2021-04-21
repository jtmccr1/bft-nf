nextflow.enable.dsl=2

//Reroot a tree and collapse the branches

process reroot {
    tag "$key"
    
    publishDir "${params.outDir}/rooted" , pattern: "*nw", mode:"copy", saveAs: {"${key}.nw"}
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
            gotree reroot outgroup -i $tree $outgroup --remove-outgroup > rooted.nw
            """
        else
            """
            gotree reroot outgroup -i $tree $outgroup > rooted.nw
            """
}


// process make_name_map {
//     tag "$key"
//     input:
//         tuple val(key),path(metadata)
//     output:
//         tuple val(key), path("*.txt")
//     shell:
//     template 'make_name_map.sh'
// }



process rename {
    tag "$key"

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



workflow prepML_tree {
	take:
	 ML_trees
	 nameMap_ch
	//  outgroup_ch
	
	main:
	
	// input = outgroup_ch.mix(ML_trees)
    //         .groupTuple(by:0,size:2,sort:{it.size()})
    //        .map(t->[t[0],t[1][0][0],t[1][1][0],t[1][1][1]])

    // make_name_map(metadata_ch)
    reroot(ML_trees)
 
    reroot.out.mix(nameMap_ch)
        .groupTuple(size:2,sort:{!it.name.contains(".nw")})
        .map(t->[t[0],t[1][0],t[1][1]]) \
    | rename \
    | collapse 
    
    emit: 
    	collapse.out
}