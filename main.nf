nextflow.enable.dsl=2

include { prepML; input_trees; make_preliminary_xml; run_preliminary_beast; process_preliminary_runs; run_DTA } from './workflows/single_step_workflows'
include {post_ML_tree; post_beastgen; post_prelim; post_DTA ;testParse} from './workflows/multistep_helper_workflows'
include {get_args;get_seeds} from "./workflows/functions"
workflow{

testParse()

}

workflow from_ML_tree {
    main:
    tree_ch = channel.from(params.runs).map({
        tree = (it.preliminary && it.preliminary.ML_tree)?it.preliminary.ML_tree:(params.preliminary.ML_tree?:params.ML_tree)
        key = it.key
        return [key,file(tree)]
    })
    template_ch =  channel.from(params.runs).map({
                   template = (it.preliminary && it.preliminary.template)?it.preliminary.template:params.preliminary.template?:params.template
                    key = it.key
                   return [key,file(template)]
    })
   post_ML_tree(tree_ch,template_ch)
}

workflow from_xml {
    main:
    xml_ch = channel.from(params.runs).map({
            xml = (it.preliminary && it.preliminary.xml)?it.preliminary.xml:(params.preliminary.xml?:params.xml)
            key = it.key
           return [key,xml]
        })
    post_beastgen(xml_ch)
}

workflow from_preliminary{
    main:
    log_ch = channel.from(params.runs).map({
        logs = (it.preliminary.logs && it.preliminary.logs.files)?it.preliminary.logs.files:(params.preliminary.logs.files?:params.files)
        files = logs.collect({file(it)})
        key = it.key

        return [key,files]
    })
    tree_ch = channel.from(params.runs).map({
        trees = (it.preliminary.trees && it.preliminary.trees.files)?it.preliminary.trees.files:(params.preliminary.trees.files?:params.trees)
        files = trees.collect({file(it)})
        key = it.key
        return [key,files]
    })
    post_prelim(log_ch,tree_ch)
}

workflow from_DTA {
    main:
    log_ch = channel.from(params.runs).map({
        logs = (it.DTA.logs && it.DTA.logs.files)?it.DTA.logs.files:(params.DTA.logs.files?:params.files)
        files = logs.collect({file(it)})
      
        key = it.key

        return [key,files]
    })
    tree_ch = channel.from(params.runs).map({
       trees = (it.DTA.trees && it.DTA.trees.files)?it.DTA.trees.files:(params.DTA.trees.files?:params.trees)
        files = trees.collect({file(it)})
        key = it.key
        return [key,files]
    })

    post_DTA(log_ch,tree_ch)
}
