nextflow.enable.dsl=2

include { build_ML_tree; process_ML_tree } from './single_steps/ML_tree'
include { treetime } from './single_steps/treetime'
include {preliminary_beastgen} from './single_steps/beastgen'
include {preliminary_beast; DTA_beast} from './single_steps/beast'
include {setupDTA;combine_runs} from './single_steps/DTA_setup'
include {DTA_post_processing} from './single_steps/DTA_post'
include {get_seeds} from "./functions"
include {align_sequences} from "./single_steps/alignment"



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


workflow post_consensus {
    take:   sample_ch
    main:

    fa_ch=channel.from(params.runs).map({
            fa = (it.fa)?it.fa:params.fa;
            key = it.key
            return [key,file(fa)]
        })

    ref_ch = channel.from(params.runs).map({
        ref = (it.reference)?it.reference:params.reference;
        key = it.key
        return [key,file(ref)]
    })
    mask_ch = channel.from(params.runs).map({
        mask = (it.masked_sites)?it.masked_sites:params.masked_sites;
        key = it.key
        return [key,mask]
    })

    align_sequences(sample_ch,fa_ch,ref_ch,mask_ch)
    if(!params.stop_after_alignment){
        post_alignment(align_sequences.out)
    }

}

workflow post_alignment {
    take: alignment_ch
    main:
   outgroup_ch =  channel.from(params.runs).map({
                   outgroup = it.outgroup?it.outgroup:params.outgroup
                   prune = it.prune_outgroup?it.prune_outgroup:params.prune_outgroup
                   key = it.key
                   return [key,outgroup,prune]
    })

    outgroup_file_ch = channel.from(params.runs).map({
                   outgroup_file_string = it.outgroup_fa?it.outgroup_fa:params.outgroup_fa
                   outgroup_file= outgroup_file_string?file(outgroup_file_string):null
                    key = it.key
                   return [key,outgroup_file]
    })

    build_ML_tree(alignment_ch,outgroup_file_ch) 
    process_ML_tree(build_ML_tree.out,outgroup_ch ,alignment_ch)
    if(!params.stop_after_tree_processing){
        post_ML_tree(process_ML_tree.out)
    }
}



//TODO make process tree
//TODO make this post processed tree
workflow post_ML_tree{
    take:   tree_ch 
    main:
    template_ch =  channel.from(params.runs).map({
                   template = (it.preliminary && it.preliminary.template)?it.preliminary.template:(params.preliminary&& params.preliminary.template)?params.preliminary.template:params.template
                    key = it.key
                   return [key,file(template)]
    })
    // treetime(tree_ch) \ //TODO
    tree_ch \
    | join(template_ch) \
    | preliminary_beastgen 

    if(!params.stop_after_beastgen){
        post_beastgen(preliminary_beastgen.out)
    }
}

workflow post_beastgen {
    take: xml_ch
        main:
        seed_ch = channel.from(params.runs).map({
            seed = (it.preliminary && it.preliminary.seed)? it.preliminary.seed:(params.preliminary && params.preliminary.seed)? params.preliminary.seed:params.seed
            n = (it.preliminary && it.preliminary.n)? it.preliminary.n:(params.preliminary && params.preliminary.n)?params.preliminary.n:params.n
            key = it.key
            //get seeds
            def random= new Random(seed)
            beast_seeds=[];
            for(int i=0;i<n;i++){
            beast_seeds.add(random.nextInt() & Integer.MAX_VALUE)
            }
           return [key,beast_seeds]
        })

        prelim_logs_ch = channel.from(params.runs).map({
        burnin = (it.preliminary && it.preliminary.logs && it.preliminary.logs.burnin)?it.preliminary.logs.burnin:
        (it.preliminary && it.preliminary.burnin)?it.preliminary.burnin:
            (params.preliminary && params.preliminary.logs && params.preliminary.logs.burnin)?params.preliminary.logs.burnin:
            (params.preliminary && params.preliminary.burnin)?params.preliminary.burnin:
            params.burnin
        
        resample =  (it.preliminary && it.preliminary.logs && it.preliminary.logs.resample)?it.preliminary.logs.resample:
        (it.preliminary && it.preliminary.resample)?it.preliminary.resample:
            (params.preliminary && params.preliminary.logs && params.preliminary.logs.resample)?params.preliminary.logs.resample:
            (params.preliminary && params.preliminary.resample)?params.preliminary.resample:
            params.resample
        return [it.key,burnin,resample]
        })

        prelim_trees_ch = channel.from(params.runs).map({
        
        burnin = (it.preliminary && it.preliminary.trees && it.preliminary.trees.burnin)?it.preliminary.trees.burnin:
        (it.preliminary && it.preliminary.burnin)?it.preliminary.burnin:
            (params.preliminary && params.preliminary.trees && params.preliminary.trees.burnin)?params.preliminary.trees.burnin:
            (params.preliminary && params.preliminary.burnin)?params.preliminary.burnin:
            params.burnin
        
        resample =  (it.preliminary && it.preliminary.trees && it.preliminary.trees.resample)?it.preliminary.trees.resample:
        (it.preliminary && it.preliminary.resample)?it.preliminary.resample:
            (params.preliminary && params.preliminary.trees && params.preliminary.trees.resample)?params.preliminary.trees.resample:
            (params.preliminary && params.preliminary.resample)?params.preliminary.resample:
            params.resample

        return [it.key,burnin,resample]
        })


        xml_ch \
        | join(seed_ch) \
        | map{ tag, xml, seeds -> tuple( groupKey(tag, seeds.size()),xml, seeds ) } \
        | transpose \
        | preliminary_beast 

        combine_runs(preliminary_beast.out.logs.groupTuple().join(prelim_logs_ch),preliminary_beast.out.trees.groupTuple().join(prelim_trees_ch))

        if(!params.stop_after_beast){
            post_prelim(combine_runs.out)
        }

}

make_seed_ch = {
seed = (it.DTA && it.DTA.seed)? it.DTA.seed :(params.DTA.seed?:params.seed)
            n = (it.DTA && it.DTA.n)? it.DTA.n :(params.DTA.n?:params.n)

            key = it.key
            //get seeds
            def random= new Random(seed)
            beast_seeds_dt2=[];
            for(int i=0;i<n;i++){
            beast_seeds_dt2.add(random.nextInt() & Integer.MAX_VALUE)
            }
           return [key,beast_seeds_dt2]
}

workflow post_prelim{
    take:  trees
    main:
        beastgen_ch = channel.from(params.runs).map({
            template = (it.DTA && it.DTA.template)? it.DTA.template:(params.DTA.template?:params.template)
            traits = (it.DTA && it.DTA.traits)?it.DTA.traits:(params.DTA.traits?:params.traits)
            options = (it.DTA && it.DTA.beastgenOptions)?it.DTA.beastgenOptions:params.dBeastgenOptions
            key = it.key
            return [key,file(traits), file(template),options]
            })
        seed_ch = channel.from(params.runs).map(make_seed_ch)
        // pocess log and tree channels

    setupDTA(trees, beastgen_ch)
    if(!params.stop_after_beastgen){
            setupDTA.out | join(seed_ch) \
            | map{ tag, xml, emptrees, seeds -> tuple( groupKey(tag, seeds.size()),xml, emptrees, seeds ) } \
            | transpose \
            | DTA_beast  
        if(!params.stop_after_DTA){
            post_DTA(DTA_beast.out.logs.groupTuple(),DTA_beast.out.trees.groupTuple())
        }
    }
}
workflow post_DTA{
    take:   logs
            trees
    main:
    //process log and tree channels
    DTA_logs_ch = channel.from(params.runs).map({
        burnin = (it.DTA && it.DTA.logs && it.DTA.logs.burnin)?it.DTA.logs.burnin:
        (it.DTA && it.DTA.burnin)?it.DTA.burnin:
            (params.DTA && params.DTA.logs && params.DTA.logs.burnin)?params.DTA.logs.burnin:
            (params.DTA && params.DTA.burnin)?params.DTA.burnin:
            params.burnin
        
        resample =  (it.DTA && it.DTA.logs && it.DTA.logs.resample)?it.DTA.logs.resample:
        (it.DTA && it.DTA.resample)?it.DTA.resample:
            (params.DTA && params.DTA.logs && params.DTA.logs.resample)?params.DTA.logs.resample:
            (params.DTA && params.DTA.resample)?params.DTA.resample:
            params.resample
        return [it.key,burnin,resample]
        })


    DTA_trees_ch = channel.from(params.runs).map({
        
       burnin = (it.DTA && it.DTA.trees && it.DTA.trees.burnin)?it.DTA.trees.burnin:
        (it.DTA && it.DTA.burnin)?it.DTA.burnin:
            (params.DTA && params.DTA.trees && params.DTA.trees.burnin)?params.DTA.trees.burnin:
            (params.DTA && params.DTA.burnin)?params.DTA.burnin:
            params.burnin
        
        resample =  (it.DTA && it.DTA.trees && it.DTA.trees.resample)?it.DTA.trees.resample:
        (it.DTA && it.DTA.resample)?it.DTA.resample:
            (params.DTA && params.DTA.trees && params.DTA.trees.resample)?params.DTA.trees.resample:
            (params.DTA && params.DTA.resample)?params.DTA.resample:
            params.resample

           return [it.key,burnin,resample]
        })

    DTA_post_processing(logs.join(DTA_logs_ch),trees.join(DTA_trees_ch))
}
