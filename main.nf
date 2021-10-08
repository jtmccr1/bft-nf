nextflow.enable.dsl=2

include { prepML; input_trees; make_preliminary_xml; process_preliminary_runs; run_DTA } from './workflows/single_step_workflows'
include {post_ML_tree; post_beastgen; post_prelim; post_DTA ;testParse; post_alignment; post_consensus} from './workflows/multistep_helper_workflows'
include {get_args;get_seeds} from "./workflows/functions"
include {process_ML_tree} from "./workflows/single_steps/ML_tree"
include {DTA_beast_jar} from "./workflows/single_steps/beast"
include {filter_fasta} from "./workflows/single_steps/filter_fasta.nf"
include {treetime} from "./workflows/single_steps/treetime"

workflow from_consensus{
    main:
    fa_ch=channel.from(params.runs).map({
        fa = (it.fa)?it.fa:params.fa;
        key = it.key
        return [key,file(fa)]
    })
    post_consensus(fa_ch)
}

workflow from_alignment {
    main:
    
    if(!params.filter){
        fa_ch=channel.from(params.runs).map({
                fa = (it.ML && it.ML.fa)?it.ML.fa:params.fa;
                key = it.key
                return [key,file(fa)]
            })
            post_alignment(fa_ch)
    }else{

        filter_ch = channel.from(params.runs).map({
                fa = it.fa?it.fa:params.fa;
                metadata = it.metadata?it.metadata:params.metadata;
                n = (it.filter && it.filter.nseq)?it.filter.nseq:params.nseq;
                weights = (it.filter && it.filter.weights)?it.filter.weights:params.weights;
                key = it.key
                return [key,file(metadata),n,weights]
            })

            fa_ch=channel.from(params.runs).map({
                fa = (it.ML && it.ML.fa)?it.ML.fa:params.fa;
                key = it.key
                return [key,file(fa)]
            })

        filter_fasta(filter_ch,fa_ch)
        post_alignment(filter_fasta.out)

    }
   
}


workflow from_ML_tree {
    main:
    tree_ch = channel.from(params.runs).map({
        tree = (it.preliminary && it.preliminary.ML_tree)?it.preliminary.ML_tree:(params.preliminary.ML_tree?:params.ML_tree)
        key = it.key
        return [key,file(tree)]
    })
   post_ML_tree(tree_ch)
}

workflow from_xml {
    main:
    xml_ch = channel.from(params.runs).map({
            xml = (it.preliminary && it.preliminary.xml)?it.preliminary.xml:(params.preliminary.xml?:params.xml)
            key = it.key
           return [key,file(xml)]
        })
    post_beastgen(xml_ch)
}

workflow from_preliminary{
    main:
    log_ch = channel.from(params.runs).map({
        logs = (it.preliminary.logs && it.preliminary.logs.files)?it.preliminary.logs.files:(params.preliminary.logs.files?:params.files)
        log_files = logs.collect({file(it)})
        log_key = it.key
        return [log_key,log_files]
    })
    tree_ch = channel.from(params.runs).map({
        trees = (it.preliminary.trees && it.preliminary.trees.files)?it.preliminary.trees.files:(params.preliminary.trees.files?:params.trees)
        tree_files = trees.collect({file(it)})
        key = it.key
        return [key,tree_files]
    })
    post_prelim(log_ch,tree_ch)
}

workflow from_DTA {
    main:
    log_ch = channel.from(params.runs).map({
        logs = (it.DTA.logs && it.DTA.logs.files)?it.DTA.logs.files:(params.DTA.logs.files?:params.files)
        log_files = logs.collect({file(it)})
      
        log_key = it.key

        return [log_key,log_files]
    })
    tree_ch = channel.from(params.runs).map({
       trees = (it.DTA.trees && it.DTA.trees.files)?it.DTA.trees.files:(params.DTA.trees.files?:params.trees)
        tree_files = trees.collect({file(it)})
        key = it.key
        return [key,tree_files]
    })

    post_DTA(log_ch,tree_ch)
}



workflow process_tree {
    outgroup_ch =  channel.from(params.runs).map({
                   outgroup = (it.ML && it.ML.outgroup)?it.ML.outgroup:params.outgroup
                   prune = (it.ML && it.ML.prune_outgroup)?it.ML.prune_outgroup:params.prune_outgroup
                    key = it.key
                   return [key,outgroup,prune]
    })
    alignment_ch =  channel.from(params.runs).map({
                   alignment = (it.ML && it.ML.alignment)?it.ML.alignment:params.alignment
                    key = it.key
                   return [key,file(alignment)]
    })
    tree_ch =  channel.from(params.runs).map({
                   tree = (it.ML && it.ML.tree)?it.ML.tree:params.tree
                    key = it.key
                   return [key,file(tree)]
    })

    process_ML_tree(tree_ch,outgroup_ch,alignment_ch)

}

workflow from_prePocessed_tree {
    outgroup_ch =  channel.from(params.runs).map({
                   outgroup = (it.ML && it.ML.outgroup)?it.ML.outgroup:params.outgroup
                   prune = (it.ML && it.ML.prune_outgroup)?it.ML.prune_outgroup:params.prune_outgroup
                    key = it.key
                   return [key,outgroup,prune]
    })
    alignment_ch =  channel.from(params.runs).map({
                   alignment = (it.ML && it.ML.alignment)?it.ML.alignment:params.alignment
                    key = it.key
                   return [key,file(alignment)]
    })
    tree_ch =  channel.from(params.runs).map({
                   tree = (it.ML && it.ML.tree)?it.ML.tree:params.tree
                    key = it.key
                   return [key,file(tree)]
    })

    process_ML_tree(tree_ch,outgroup_ch,alignment_ch);
     post_ML_tree(process_ML_tree.out);

}

make_seed_ch = {
seed = (it.DTA && it.DTA.seed)? it.DTA.seed :(params.DTA.seed?:params.seed)
            n = (it.DTA && it.DTA.n)? it.DTA.n :(params.DTA.n?:params.n)

            key = it.key
            //get seeds
            def random= new Random(seed)
            beast_seeds_dta=[];
            for(int i=0;i<n;i++){
            beast_seeds_dta.add(random.nextInt() & Integer.MAX_VALUE)
            }
           return [key,beast_seeds_dta]
}
workflow DTA {

     seed_ch = channel.from(params.runs).map(make_seed_ch)

         xml_ch = channel.from(params.runs).map({
            xml = (it.DTA && it.DTA.xml)? it.DTA.xml :(params.DTA.xml?:params.xml)
          
            key = it.key
            //get xmls
            
           return [key,xml]
        })
        emptrees_ch = channel.from(params.runs).map({
            emptrees = (it.DTA && it.DTA.emptrees)? it.DTA.emptrees :(params.DTA.emptrees?:params.emptrees)
            key = it.key
            //get xmls
           return [key,emptrees]
        })
    xml_ch.join(emptrees_ch)\
            | join(seed_ch) \
            | map{ tag, xml, emptrees, seeds -> tuple( groupKey(tag, seeds.size()),xml, emptrees, seeds ) } \
            | transpose \
            | DTA_beast_jar 

}