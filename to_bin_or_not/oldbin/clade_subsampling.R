library(tidyverse,quietly = T)
require(lubridate,quietly = T)

get_date<-function(x){
  str_split(x,"\\|")[[1]][2]
}
get_lineage<-function(x){
  gsub("\\.clades\\.tsv","",x)
}
p<-"./exploratory/2021-03-05/extracted_clades/"
read_and_label<-function(x){
  p<-"./exploratory/2021-03-05/extracted_clades/"
  read_tsv(paste0(c(p,x),collapse = ''))%>%mutate(file=x)
}

sample_clade<-function(clade,nonUK_min,UK_min,UK_frac){
  if(length(unique(clade$location))!=1){
    stop("Not a monophyletic clade")
  }
  if(nonUK_min>0 & grepl("NonUK",clade$location[1])){
    return(slice_sample(clade,n=nonUK_min,weight_by=w,replace=F))
  }
  
  size<-nrow(clade)
  if(size<UK_min+1){
    return(clade)
  }
  n<-max(UK_min,round(size*UK_frac))
  sorted<-arrange(clade,desc(date))
  latest<-head(sorted,n=2)
  earliest<-tail(sorted,n=3)
  
  sample<-rbind(earliest,latest)
  if(n>UK_min){
    leftovers<-slice_sample(sorted[3:(size-3),],n=(n-UK_min),replace=F,weight_by=w) 
    sample<-rbind(leftovers,sample)
  }
  if(length(which(duplicated(sample)))>0){
    cat("duplicated!")
  }
  
  return(sample)
}

main<-function(){
  args <- commandArgs(trailingOnly = TRUE)
  cat(args)
  if("-i"%in% args){
  i<-args[which(args=="-i")+1]
  # p<-args[which(args=="-p")+1]
  
  UK_min<-ifelse("-UK-min" %in% args,as.numeric(args[which(args=="-UK-min")+1]),5)
  UK_frac<-ifelse("-UK-frac" %in% args,as.numeric(args[which(args=="-UK-frac")+1]),0.1)

  NonUK_min<-ifelse("-NonUK-min" %in% args,numeric(args[which(args=="-NonUK-min")+1])+1,1)

  tbl <-read_tsv(i)%>%
    mutate(date=sample_date) %>%
    mutate(epi_time=paste0(epiyear(date),'-',epiweek(date)))
  
  w<-tbl %>% group_by(epi_time)%>% tally() %>% mutate(w=1/n)
  
  tbl<-tbl%>% left_join(w)
  
  clades<-tbl%>% filter(!is.na(Clade)) #singletons or not annotated
  singletons<-tbl%>% filter(is.na(Clade))
  clade_sum<-clades %>%
    group_by(Clade) %>%
    summarize(earliest_date=min(date),size=n(),duration=as.double(difftime(max(date),min(date)),units="days"))
  
  write_tsv(clade_sum,"clade_summary.tsv")
  
  #TODO write summary
  

  (monophyletic_subset_collapsed<-(clades %>%group_by(Clade) %>% nest()%>%
                                     mutate(sampled=map(data,~sample_clade(.,NonUK_min,UK_min,UK_frac))) %>%
                                     select(sampled)%>%unnest(cols=c(sampled))))
  
  samples_c<-rbind(singletons,monophyletic_subset_collapsed)
  #TODO get lineage
  
  write_lines(samples_c$taxa, "taxa.txt")

  }else{
    cat(" Sampling by time and clade. monophyletic clades will be down sampled by a percentage in an attempt to make samples even through time.
        required arguments are -i <infile> 
        ")
    cat("optional agruments are:
        -UK-min<int> default 5
        -UK-frac<double> defualt 0.1
        -nonUK-min<int> default 1
        ")
  }
}

main()





