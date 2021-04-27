nextflow.enable.dsl=2


include { treetime } from './single_steps/treetime'
include { prepML_tree } from './single_steps/prepML_tree'
include {preliminary_beastgen} from './single_steps/beastgen'
include {preliminary_beast; DTA_beast} from './single_steps/beast'
include {setupDTA} from './single_steps/DTA_setup'
include {DTA_post_processing} from './single_steps/DTA_post'
include {get_seeds} from "./functions"



workflow testParse {
    main:
        beastgen_ch = channel.from(params.runs).map({
            template = (it.DTA && it.DTA.template)? it.DTA.template : params.DTA.template?:params.template
            traits = (it.DTA!=null && it.DTA.traits!=null)? it.DTA.traits : params.DTA.traits?:params.traits
            key = it.key;
            return [key,file(traits), file(template)];
            }).view();

        seed_ch = channel.from(params.runs).map({
            seed = (it.DTA && it.DTA.seed)? it.DTA.seed :(params.DTA.seed?:params.seed)
            n = (it.DTA && it.DTA.n)? it.DTA.n :(params.DTA.n?:params.n)
            key = it.key;
            //get seeds
            def random= new Random(seed)
            beast_seeds=[];
            for(int i=0;i<n;i++){
            beast_seeds.add(random.nextInt() & Integer.MAX_VALUE)
            }
           return [key,beast_seeds]
        }).view();
}

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
            seed = (it.preliminary && it.preliminary.seed)? it.preliminary.seed:(params.preliminary.seed?:params.seed)
            n = (it.preliminary && it.preliminary.n)? it.preliminary.n:(params.preliminary.n?:params.n)
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
        | transpose \
        | preliminary_beast 
        post_prelim(preliminary_beast.out.logs.groupTuple(),preliminary_beast.out.trees.groupTuple())
}


workflow post_prelim{
    take:   logs
            trees
    main:
        beastgen_ch = channel.from(params.runs).map({
            template = (it.DTA && it.DTA.template)? it.DTA.template:(params.DTA.template?:params.template)
            traits = (it.DTA && it.DTA.traits)?it.DTA.traits:(params.DTA.traits?:params.traits)
            key = it.key
            return [key,file(traits), file(template)]
            })
        seed_ch = channel.from(params.runs).map({
            seed = (it.DTA && it.DTA.seed)? it.DTA.seed :(params.DTA.seed?:params.seed)
            n = (it.DTA && it.DTA.n)? it.DTA.n :(params.DTA.n?:params.n)
           
            key = it.key
            //get seeds
            def random= new Random(seed)
            beast_seeds=[];
            for(int i=0;i<n;i++){
            beast_seeds.add(random.nextInt() & Integer.MAX_VALUE)
            }
           return [key,beast_seeds]
        })
        // pocess log and tree channels
    prelim_logs_ch = channel.from(params.runs).map({
        burnin = (it.preliminary && it.preliminary.logs && it.preliminary.logs.burnin)?it.preliminary.logs.burnin:(params.preliminary.logs.burnin?:params.burnin)
        resample =  (it.preliminary && it.preliminary.logs && it.preliminary.logs.resample)?it.preliminary.logs.resample:(params.preliminary.logs.resample?:params.resample)
        return [it.key,burnin,resample]
        })
    prelim_trees_ch = channel.from(params.runs).map({
        burnin = (it.preliminary && it.preliminary.trees && it.preliminary.trees.burnin)?it.preliminary.trees.burnin:(params.preliminary.trees.burnin?:params.burnin)
        resample =  (it.preliminary && it.preliminary.trees && it.preliminary.trees.resample)?it.preliminary.trees.resample:(params.preliminary.trees.resample?:params.resample)
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
        burnin = (it.DTA && it.DTA.logs && it.DTA.logs.burnin)?it.DTA.logs.burnin:(params.DTA.logs.burnin?:params.burnin)
        resample =  (it.DTA && it.DTA.logs && it.DTA.logs.resample)?it.DTA.logs.resample:(params.DTA.logs.resample?:params.resample)
        return [it.key,burnin,resample]
    })
    DTA_trees_ch = channel.from(params.runs).map({
        burnin = (it.DTA && it.DTA.trees && it.DTA.trees.burnin)?it.DTA.trees.burnin:(params.DTA.trees.burnin?:params.burnin)
        resample =  (it.DTA && it.DTA.trees && it.DTA.trees.resample)?it.DTA.trees.resample:(params.DTA.trees.resample?:params.resample)
        return [it.key,burnin,resample]
    })   
    DTA_post_processing(logs.join(DTA_logs_ch),trees.join(DTA_trees_ch))
}
