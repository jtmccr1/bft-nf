def get_value(obj,keys){
    savedObj = obj
    currentObj = obj
    for (key in keys) {
        if(currentObj!=null && currentObj.containsKey(key)){
            currentObj=currentObj[key]
            obj=savedObj
        }else{
            return null;
        }
    }
    return currentObj
    
}
def get_args(it,params,keys){
    value = get_value(it,keys);
    while(value==null && keys.size>0){
        value = get_value(params,keys)
        keys.remove(0)
    }
    return value;
}

def get_seeds(seed,n){
    def random= new Random(seed)

    beast_seeds=[];
    for(int i=0;i<n;i++){
        beast_seeds.add(random.nextInt() & Integer.MAX_VALUE)
    }
    return beast_seeds
}