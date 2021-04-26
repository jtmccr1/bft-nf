nextflow.enable.dsl=2


include { treetime } from './single_steps/treetime'
include { prepML_tree } from './single_steps/prepML_tree'
include {preliminary_beastgen} from './single_steps/beastgen'
include {preliminary_beast; DTA_beast;get_seeds} from './single_steps/beast'
include {setupDTA} from './single_steps/DTA_setup'
include {DTA_post_processing} from './single_steps/DTA_post'
include {get_args} from "./functions"


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
            seed = get_args(it,params,["preliminary","seed"]) //it.preliminary.seed?:(params.preliminary.seed?:params.seed)
            n = get_args(it,params,["preliminary","n"]) //it.preliminary.n?:(params.preliminary.n?:params.n)
            key = it.key
           return [key,get_seeds(seed,n)]
        })
        xml_ch \
        | join(seed_ch) \
        | transpose \
        | preliminary_beast 
        post_prelim(preliminary_beast.out.logs.groupTuple(),preliminary_beast.out.trees.groupTuple())
}


workflow post_prelim{
    take:   logs
            trees
    main:
        beastgen_ch = channel.from(params.runs).map({
            print(params.containsKey("DTA"))
            template = get_args(it,params,["DTA","template"]) //it.DTA.template?:(params.DTA.template?:params.template)
            traits = get_args(it,params,["DTA","traits"]); //it.DTA.traits?:(params.DTA.traits?:params.traits)
            key = it.key
            return [key,file(traits), file(template)]
            })
        seed_ch = channel.from(params.runs).map({
            seed = get_args(it,params,["DTA","seed"])//it.DTA.seed?:(params.DTA.seed?:params.seed)
            n = get_args(it,params,["DTA","n"])//it.DTA.n?:(params.DTA.n?:params.n)
            key = it.key
            
           return [key,get_seeds(seed,n)]
        })
        // pocess log and tree channels
    prelim_logs_ch = channel.from(params.runs).map({
        burnin =  resample =  get_args(it,params,["preliminary","logs","burnin"])
        resample =  get_args(it,params,["preliminary","logs","resample"])
        return [it.key,burnin,resample]
        })
    prelim_trees_ch = channel.from(params.runs).map({
        burnin = get_args(it,params,["preliminary","trees","burnin"]) //it.preliminary.trees.burnin?:(params.preliminary.trees.burnin?:params.trees_burnin)
        resample =  get_args(it,params,["preliminary","trees","resample"]) //it.preliminary.trees.resample?:(params.preliminary.trees.resample?:params.trees_resample)
        return [it.key,burnin,resample]
        })

    setupDTA(logs.join(prelim_logs_ch), trees.join(prelim_trees_ch),beastgen_ch) \
            | join(seed_ch) |transpose \
            | DTA_beast  

    post_DTA(DTA_beast.out.logs.groupTuple(),DTA_beast.out.trees.groupTuple())
}
workflow post_DTA{
    take:   logs
            trees
    main:
//process log and tree channels
    DTA_logs_ch = channel.from(params.runs).map({
        burnin = get_args(it,params,["DTA","logs","burnin"]) //it.DTA.logs.burnin?:(params.DTA.logs.burnin?:params.burnin)
        resample = get_args(it,params,["DTA","logs","resample"]) //it.DTA.logs.resample?:(params.DTA.logs.resample?:params.resample)
        return [it.key,burnin,resample]
    })
    DTA_trees_ch = channel.from(params.runs).map({
        burnin = get_args(it,params,["DTA","trees","burnin"]) //it.DTA.trees.burnin?:(params.DTA.trees.burnin?:params.burnin)
        resample = get_args(it,params,["DTA","trees","resample"]) //it.DTA.trees.resample?:(params.DTA.trees.resample?:params.resample)
        return [it.key,burnin,resample]
    })   
    DTA_post_processing(logs.join(DTA_logs_ch),trees.join(DTA_trees_ch))
}
