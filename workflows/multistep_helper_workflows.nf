nextflow.enable.dsl=2


include { treetime } from './single_steps/treetime'
include { prepML_tree } from './single_steps/prepML_tree'
include {preliminary_beastgen} from './single_steps/beastgen'
include {preliminary_beast; DTA_beast;get_seeds} from './single_steps/beast'
include {setupDTA} from './single_steps/DTA_setup'
include {DTA_post_processing} from './single_steps/DTA_post'

workflow post_ML_tree{
    take:   tree_ch 
            template_ch
    main:
    treetime(tree_ch) \
    | join(template_ch) \
    | preliminary_beastgen \
    | post_beastgen
}

workflow post_beastgen {
    take: xml_ch
        main:
        seed_ch = channel.from(params.runs).map({
            seed = it.preliminary.seed?:(params.preliminary.seed?:params.seed)
            n = it.preliminary.n?:(params.preliminary.n?:params.n)
            key = it.key
           return [key,get_seeds(seed,n)]
        })
        xml_ch.join(seed_ch) | preliminary_beast 
        post_prelim(preliminary_beast.out.logs.groupTuple(),preliminary_beast.out.trees.groupTuple)
}


workflow post_prelim{
    take:   logs
            trees
    main:
        beastgen_ch = channel.from(params.runs).map({
            template = it.DTA.template?:(params.DTA.template?:params.template)
            traits = it.DTA.traits?:(params.DTA.traits?:params.traits)
            key = it.key
            return [key,file(traits), file(template)]
            })
        seed_ch = channel.from(params.runs).map({
            seed = it.DTA.seed?:(params.DTA.seed?:params.seed)
            n = it.DTA.n?:(params.DTA.n?:params.n)
            key = it.key
            
           return [key,get_seeds(seed,n)]
        })
        // pocess log and tree channels
    prelim_logs_ch = channel.from(params.runs).map({
        burnin = it.preliminary.logs.burnin?:(params.preliminary.logs.burnin?:params.logs_burnin)
        resample = it.preliminary.logs.resample?:(params.preliminary.logs.resample?:params.logs_resample)
        return [it.key,burnin,resample]
        })
    prelim_trees_ch = channel.from(params.runs).map({
        burnin = it.preliminary.trees.burnin?:(params.preliminary.trees.burnin?:params.trees_burnin)
        resample = it.preliminary.trees.resample?:(params.preliminary.trees.resample?:params.trees_resample)
        return [it.key,burnin,resample]
        })

    setupDTA(logs.join(prelim_logs_ch), trees.join(prelim_trees_ch),beastgen_ch) \
            | join(seed_ch) |transpose | view \
            | DTA_beast  

    post_DTA(DTA_beast.out.logs.groupTuple(),DTA_beast.out.trees.groupTuple())
}
workflow post_DTA{
    take:   logs
            trees
    main:
//process log and tree channels
    DTA_logs_ch = channel.from(params.runs).map({
        burnin = it.DTA.logs.burnin?:(params.DTA.logs.burnin?:params.logs_burnin)
        resample = it.DTA.logs.resample?:(params.DTA.logs.resample?:params.logs_resample)
        return [it.key,burnin,resample]
    })
    DTA_trees_ch = channel.from(params.runs).map({
        burnin = it.DTA.trees.burnin?:(params.DTA.trees.burnin?:params.trees_burnin)
        resample = it.DTA.trees.resample?:(params.DTA.trees.resample?:params.trees_resample)
        return [it.key,burnin,resample]
    })   
    DTA_post_processing(logs.join(DTA_logs_ch),trees.join(DTA_trees_ch))
}
