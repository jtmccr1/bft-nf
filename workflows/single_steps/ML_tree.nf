nextflow.enable.dsl=2


process cat {
     tag "$key"
    input:
        tuple val(key), path(alignment),path(outgroup)
    output:
        tuple val(key), path("all.fa")

"""
cat $alignment $outgroup > all.fa
"""
}

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

/*
 * reroot a tree and optionally prune the outgroup. Unroots the final tree to start at the node
 */
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
            gotree reroot outgroup -i $tree "$outgroup" --remove-outgroup | gotree unroot > rooted.nw
            """
        else
            """
            gotree reroot outgroup -i $tree "$outgroup" | gotree unroot> rooted.nw
            """
}
/*
* rename the tips in a tree
*/

process rename {
    tag "$key"
    publishDir "${params.outDir}/ML_tree" , pattern: "*nw", saveAs: {"${key}.nw"}
    input:
    tuple val(key), path(tree), path(nameMap)
    output:
        tuple val(key), path("renamed.nw")
"""
gotree rename -i $tree -m $nameMap -o renamed.nw
"""

}

/*
* collapse brnaches below a threshold
*/
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


/*
* Refine a tree using treetime keep the polytomies and root.
*/
process refine {
    tag "$key"
    input:
    tuple val(key),path(tree),path(alignment)
    output:
    tuple val(key), path("refined.tree"), path('node.data.json')

"""
#make date file
echo -e 'name\tdate'>input_dates.tsv;
fertree extract taxa -i $tree | \
awk '{n=split(\$1,a,"\\|");printf "%s\\t%s\\n",\$1,a[n]}'>>input_dates.tsv;

augur refine \
            --tree $tree \
            --metadata input_dates.tsv \
            --alignment $alignment \
            --output-tree refined.tree \
            --output-node-data node.data.json \
            --timetree \
            --keep-root \
            --keep-polytomies \
            --clock-rate $params.clock_rate \
            --date-inference marginal \
            --divergence-unit mutations \
            --no-covariance \
            --clock-filter-iqd $params.clock_filter
"""
}


/*
* Scale the branches of a tree to match the divergence and time 
* from a refine command resolve the time tree and output as one nexus
*/
process process_refined_tree {
    publishDir "${params.outDir}/input_trees" , pattern: "*nexus",  saveAs: {it.replaceAll("scaled",key)}
    tag "$key"
    input:
        tuple val(key), path(refined_tree), path(node_data)
    output:
        tuple val(key), path("scaled.nexus")

    """
    jq -r '.nodes | to_entries[] |[.key, .value.branch_length] | @tsv' $node_data > brlen.mut.tsv;
    jq -r '.nodes | to_entries[] |[.key, .value.clock_length] | @tsv' $node_data > brlen.clock.tsv;


    RUST_LOG=WARN fertree brlen set -f brlen.mut.tsv  -i $refined_tree | sed  's/NODE_[^:;]*//g' | gotree collapse length -l 0.5  >scaled.tree;
    RUST_LOG=WARN fertree brlen set -f brlen.clock.tsv  -i $refined_tree | fertree resolve evenly | sed  's/NODE_[^:;]*//g' >>scaled.tree;

    gotree reformat nexus -i scaled.tree -o scaled.nexus;
    """
}

/*
* finalize alignment and rename to match the final tips in the tree
*/

process finalize_alignment {
     publishDir "${params.outDir}/alignment" , pattern: "*fa",  saveAs: {it.replaceAll("final_alignment",key)}
     tag "$key"
     input:
        tuple val(key), path(nexus_tree), path(alignment)
    output:
        tuple val(key), path("final_alignment.fa")
"""
# make the tip text
RUST_LOG=WARN fertree extract taxa -i $nexus_tree -n | sort | uniq >tips.txt
python3 $projectDir/bin/get_fasta_from_IDs.py $alignment tips.txt > final_alignment.fa
"""
}


workflow process_ML_tree {
    take:
	tree_ch
    outgroup_ch
    alignment_ch
    
    main:
    tree_ch.join(outgroup_ch) \
    | reroot \
    | collapse \
    | join(alignment_ch)
    | refine \
    | process_refined_tree \
    | join(alignment_ch) \
    | finalize_alignment

    emit: 
    	process_refined_tree.out 
}


workflow build_ML_tree {
	take:
	 alignment_ch
     outgroup_ch
	
	main:
	alignment_ch.join(outgroup_ch) \
    | cat \
    | iqtree2 

    emit: 
    	iqtree2.out
}
