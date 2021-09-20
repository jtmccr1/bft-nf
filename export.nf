nextflow.enable.dsl=2
params.treetime_options=""





/*
* Refine a tree using treetime keep the polytomies and root.
*/



process refine {
    input:
    path(tree)
    path(alignment)
    path(metadata)
    output:
    path("refined.tree"), emit: tree
    path('node.data.json'), emit: node_data

"""
augur refine \
            --tree $tree \
            --alignment $alignment \
            --metadata $metadata \
            --output-tree refined.tree \
            --output-node-data node.data.json \
            --divergence-unit mutations \
            ${params.treetime_options}
"""
}


process ancestral {
    input:
     path(tree)
     path(alignment)
    output:
    path('nt_muts.json')

"""
augur ancestral \
            --tree $tree \
            --alignment $alignment \
            --output-node-data nt_muts.json \
            --inference joint \
            --infer-ambiguous
"""
}

// TODO not harcoded reference
process translate {
    input:
    path(tree)
    path(nt_muts)
    output:
    path('aa_muts.json')

"""
augur translate \
            --tree $tree \
            --ancestral-sequences $nt_muts \
            --reference-sequence ${projectDir}/reference/reference_seq.gb \
            --output-node-data aa_muts.json
"""
}

process v2 {
    publishDir "${params.outDir}/auspice" , pattern: "final.json", mode:"move", saveAs: {"${key}.json"}

    input:
    path(tree)
    path(nt_muts)
    path(aa_muts)
    path(node_data)
    path(metadata)
    path(config)
    output:
    path('final.json')

"""
augur export v2 \
            --tree $tree \
             --node-data $nt_muts $aa_muts $node_data \
             --auspice-config $config \
             --metadata $metadata \
             --output final.json	
"""
}



workflow {
    tree_ch= channel.fromPath(params.tree)
    alignment_ch =channel.fromPath(params.alignment)
    metadata_ch = channel.fromPath(params.metadata)
    config_ch = channel.fromPath(params.auspice_config)

    refine(tree_ch,alignment_ch,metadata_ch)
    refine.out.tree.view()

    ancestral(refine.out.tree, alignment_ch)

    translate(refine.out.tree, ancestral.out)

    v2(refine.out.tree, refine.out.node_data,ancestral.out, translate.out,metadata_ch,config_ch)

}

