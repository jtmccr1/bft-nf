nextflow.enable.dsl=2

// This makes xml file directories from nexus trees and xml files
def noExtension(path){
    path.name.take(path.name.lastIndexOf('.')).toString()
}

process beastgen_process{
    tag "$key"
    publishDir "${params.outDir}/xml" , pattern: "*xml", mode:"copy", saveAs: {it.replaceAll("beast",key)}
    input:
        tuple val(key),path(trees), path(xml_template)
    output:
        tuple val(key), path('beast.xml')
"""
cp $xml_template ./local_template

beastgen -date_order -1 -date_prefix "|" -date_precision \
    -D "outputStem=${key}" \
    -tree $trees \
    local_template \
    $trees \
    beast.xml 
"""

}

workflow preliminary_beastgen{
    take:trees_templates
	main:
   trees_templates | beastgen_process
   emit:
   beastgen_process.out
}
