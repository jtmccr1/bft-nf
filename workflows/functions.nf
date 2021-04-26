def get_value(obj,keys){
    currentObj = obj;
    for (key in keys) {
        if(currentObj.containsKey(key)){
            currentObj=currentObj[key]
        }else{
            return null;
        }
    }
    return currentObj
    
}
def get_args(it,params,keys){
    // println(keys)
    value = get_value(it,keys);
    while(value==null && keys.size>0){
        value = get_value(params,keys)
        keys.remove(0)
    }
    // println(value)
    return value;
}