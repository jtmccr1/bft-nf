nextflow.enable.dsl=2


include { treetime } from './single_steps/treetime'
include { prepML_tree } from './single_steps/prepML_tree'
// include { process_clades } from './single_steps/processClades'
include {preliminary_beastgen} from './single_steps/beastgen'
include {preliminary_beast; DTA_beast} from './single_steps/beast'
include {setupDTA} from './single_steps/DTA_setup'
include {DTA_post_processing} from './single_steps/DTA_post'
include {get_seeds} from "./functions"

workflow prepML{
    main:
        tree_ch = channel.from(params.runs).map({
            tree = it.preliminary.Ml_tree?:(params.preliminary.Ml_tree?:params.Ml_tree)
            outgroup = it.preliminary.outgroup?:(params.preliminary.outgroup?:params.outgroup)
            prune = it.preliminary.prune?:(params.preliminary.prune?:params.prune)
            return [it.key,file(tree),outgroup,prune]
        })
        nameMap_ch = channel.from(params.runs).map({
            nameMap = it.preliminary.prune?:(params.preliminary.prune?:params.prune)
            return [it.key,file(nameMap)]
        })
        prepML(tree_ch,nameMap_ch)
}

workflow input_trees{
    main:
          tree_ch = channel.from(params.runs).map({
            tree = it.preliminary.Ml_tree?:(params.preliminary.Ml_tree?:params.Ml_tree)
            return [it.key,file(tree)]
          })
        treetime(tree_ch)
}

workflow make_preliminary_xml{
    main:
        tree_ch = channel.from(params.runs).map({
            template = n.preliminary.template?:params.preliminary.template?:params.template
            template = n.preliminary.input_trees?:params.preliminary.input_trees?:params.input_trees
            key = it.key            
            [key,file(input_trees),file(template)]
        })
        preliminary_beastgen(tree_ch)
}

//TODO import run beast with all the bells and whistles 
workflow run_beast{
    main:
        xml_ch = channel.from(params.runs).map({
            xml = it.xml?:params.xml
            key = it.key
           return [key,xml]
        })
         seed_ch = channel.from(params.runs).map({
            seed = it.seed?:params.seed
            n = it.n?:params.n
           
            key = it.key
            //get seeds
            def random= new Random(seed)
            beast_seeds=[];
            for(int i=0;i<n;i++){
            beast_seeds.add(random.nextInt() & Integer.MAX_VALUE)
            }
           return [key,beast_seeds]
        })
        xml_ch \
        | join(seed_ch) \
        | map{ tag, xml, seeds -> tuple( groupKey(tag, seeds.size()),xml, seeds ) } \
        | transpose \
        | preliminary_beast 

}

workflow process_preliminary_runs{
    main:
    log_ch = channel.from(params.runs).map({
        logs = it.preliminary.logs.files?:(params.preliminary.logs.files?:params.logs_files)
        files = logs.map(f->file(f))
        burnin = it.preliminary.logs.burnin?:(params.preliminary.logs.burnin?:params.logs_burnin)
        resample = it.preliminary.logs.resample?:(params.preliminary.logs.resample?:params.logs_resample)
        key = it.key
        return [key,files,burnin,resample]
    })
    tree_ch = channel.from(params.runs).map({
       trees = it.preliminary.trees.files?:(params.preliminary.trees.files?:params.trees)
        files = trees.map(f->file(f))
        burnin = it.preliminary.trees.burnin?:(params.preliminary.trees.burnin?:params.trees_burnin)
        resample = it.preliminary.trees.resample?:(params.preliminary.trees.resample?:params.trees_resample)
        key = it.key
        return [key,files,burnin,resample]
    })
        beastgen_ch = channel.from(params.runs).map({
            template = it.DTA.template?:(params.DTA.template?:params.template)
            traits = it.DTA.traits?:(params.DTA.traits?:params.traits)
            key = it.key
            return [[key,file(template)], [it.key,file(traits)]]
            })
    setupDTA(log_ch,tree_ch,beastgen_ch)
}


workflow run_DTA {
    main:
    xml_ch = channel.from(params.runs).map({    
            xml = it.DTA.xml?:(params.DTA.xml?:params.xml)
            key = it.key
           return [key,xml]
        })
    seed_ch = channel.from(params.runs).map({
            seed = it.DTA.seed?:(params.DTA.seed?:params.seed)
            n = it.DTA.n?:(params.DTA.n?:params.n)
            key = it.key
            //get seeds
            def random= new Random(seed)
            beast_seeds=[];
            for(int i=0;i<n;i++){
            beast_seeds.add(random.nextInt() & Integer.MAX_VALUE)
            }
           return [key,beast_seeds]
        })
    DTA_beast(xml_ch.combine(seed_ch))
}
