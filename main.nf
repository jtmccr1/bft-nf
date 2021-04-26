nextflow.enable.dsl=2

include { prepML; input_trees; make_preliminary_xml; run_preliminary_beast; process_preliminary_runs; run_DTA } from './workflows/single_step_workflows'
include {post_ML_tree; post_beastgen; post_prelim; post_DTA } from './workflows/multistep_helper_workflows'
include {get_args} from "./workflows/functions"
include {get_seeds} from './workflows/single_steps/beast'
workflow{
channel.from(params.runs).map({
        seed = get_args(it,params,["preliminary","seed"])
        n = get_args(it,params,["preliminary","seed"])

         key = it.key
        return [key,get_seeds(seed,n)]
}).view()
}

workflow from_ML_tree {
    main:
    tree_ch = channel.from(params.runs).map({
        tree = get_args(it,params,["preliminary","ML_tree"]); //it.preliminary.ML_tree?:(params.preliminary.ML_tree?:params.ML_tree)
        key = it.key
        return [key,file(tree)]
    })
    template_ch =  channel.from(params.runs).map({
                   template = get_args(it,params,["preliminary","template"]) // it.preliminary.template?:params.preliminary.template?:params.template
                    key = it.key
                   return [key,file(template)]
    })
   post_ML_tree(tree_ch,template_ch)
}

workflow from_xml {
    main:
    xml_ch = channel.from(params.runs).map({
            xml = get_args(it,params,["preliminary","xml"]) //it.preliminary.xml?:(params.preliminary.xml?:params.xml)
            key = it.key
           return [key,xml]
        })
    post_beastgen(xml_ch)
}

workflow from_preliminary{
    main:
    log_ch = channel.from(params.runs).map({
        logs = get_args(it,params,["preliminary","logs","files"]) //it.preliminary.logs.files?:(params.preliminary.logs.files?:params.files)
        files = logs.collect({file(it)})
        key = it.key

        return [key,files]
    })
    tree_ch = channel.from(params.runs).map({
        trees = get_args(it,params,["preliminary","trees","files"]) //it.preliminary.trees.files?:(params.preliminary.trees.files?:params.trees)
        files = trees.collect({file(it)})
        key = it.key
        return [key,files]
    })
    post_prelim(log_ch,tree_ch)
}

workflow from_DTA {
    main:
    log_ch = channel.from(params.runs).map({
        logs = get_args(it,params,["DTA","logs","files"]) //it.DTA.logs.files?:(params.DTA.logs.files?:params.files)
        files = logs.collect({file(it)})
      
        key = it.key

        return [key,files]
    })
    tree_ch = channel.from(params.runs).map({
       trees = get_args(it,params,["DTA","logs","files"]) //it.DTA.trees.files?:(params.DTA.trees.files?:params.trees)
        files = trees.collect({file(it)})
        key = it.key
        return [key,files]
    })

    post_DTA(log_ch,tree_ch)
}
