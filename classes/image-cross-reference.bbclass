# Copyright (C) 2017 Inango Systems Ltd
# Released under the ******  license (see COPYING.INANGO for the terms)

inherit image_types
inherit cross-reference
DESCRIPTION = "Build cross-reference for include files and merges tags files for all build packages"

INCLUDE_CROSS_REFERENCE_TAG_NAME = "include.tag"
INCLUDE_CROSS_REFERENCE_ADDITIONAL_TAG_FILE  = "include.atf"
INCLUDE_CROSS_REFERENCE_TAG_DIR = "${WORKDIR}/include-cross-reference"
INCLUDE_CROSS_REFERENCE_TAG_FILE_PATH ?= "${INCLUDE_CROSS_REFERENCE_TAG_DIR}/${INCLUDE_CROSS_REFERENCE_TAG_NAME}"

INCLUDE_CROSS_REFERENCE_CMD_ctags = "ctags --file-scope=no --recurse -f ${INCLUDE_CROSS_REFERENCE_TAG_FILE_PATH} `pwd`"
INCLUDE_CROSS_REFERENCE_CMD_cscope = "cscope -Rb -f ${INCLUDE_CROSS_REFERENCE_TAG_FILE_PATH}"

CROSS_REFERENCE_MERGE_DIR ?= "${WORKDIR}/merge-cross-reference"
CROSS_REFERENCE_ALLTAGS_FILENAME = "all_tags"
CROSS_REFERENCE_ALLTAGS_PATH = "${CROSS_REFERENCE_MERGE_DIR}/${CROSS_REFERENCE_ALLTAGS_FILENAME}"
CROSS_REFERENCE_MERGE_CMD_ctags = "find ${CROSS_REFERENCE_SSTATE_CACHES_DIR} -type f -name '*.tag' -exec cat \{} \; | sort -u > ${CROSS_REFERENCE_ALLTAGS_PATH}"

CROSS_REFERENCE_LIST_OF_TAGS_NAME = "list_of_tags"
CROSS_REFERENCE_LIST_OF_TAGS_PATH ?= "${CROSS_REFERENCE_MERGE_DIR}/${CROSS_REFERENCE_LIST_OF_TAGS_NAME}"

do_merge_all_cross_reference[doc] = "Merges multiple tag files"

python do_merge_all_cross_reference() {
    if d.getVar('CROSS_REFERENCE_MERGE_CMD_' + d.getVar('CROSS_REFERENCE_TOOL', True), True) is None:
        bb.fatal("Command for merge tags file with " + d.getVar('CROSS_REFERENCE_TOOL', True) + " utility is not specified")

    if not os.path.exists(d.getVar('CROSS_REFERENCE_MERGE_DIR', True)):
        os.mkdir(d.getVar('CROSS_REFERENCE_MERGE_DIR', True))
    retvalue = os.system(d.getVar("CROSS_REFERENCE_MERGE_CMD_" + d.getVar('CROSS_REFERENCE_TOOL', True), True))

    if retvalue != 0:
        if d.getVar('CROSS_REFERENCE_ERROR_ON_FAILURE', True) == "error":
            bb.fatal("Can't merge tags file for image: " + d.getVar('PN', True))
        elif d.getVar('CROSS_REFERENCE_ERROR_ON_FAILURE', True) == "warning":
            bb.warn("Can't merge tags file for image: " + d.getVar('PN', True))
        else:
            bb.plain("Can't merge tags file for image: " + d.getVar('PN', True))
    else:
        execute_command = 'find %s -name %s -type f | xargs cat > %s' % (d.getVar('TMPDIR', True), "*.atf", d.getVar('CROSS_REFERENCE_LIST_OF_TAGS_PATH', True))
        os.system(execute_command)
        bb.note("Merges tag files was succsesfull for image: " + d.getVar('PN', True))

}

addtask merge_all_cross_reference after do_include_cross_reference before do_build

python do_include_cross_reference() {
    param = {
        'package_name': d.getVar('PN', True),
        'source': d.getVar('STAGING_INCDIR',True),
        'cross_reference':{
            'tool': d.getVar('CROSS_REFERENCE_TOOL', True),
            'command': d.getVar("INCLUDE_CROSS_REFERENCE_CMD_" + d.getVar('CROSS_REFERENCE_TOOL', True), True),
            'tag_dir': d.getVar('INCLUDE_CROSS_REFERENCE_TAG_DIR', True),
            'tag_file_path': d.getVar('INCLUDE_CROSS_REFERENCE_TAG_FILE_PATH', True),
            'tag_name': d.getVar('INCLUDE_CROSS_REFERENCE_TAG_NAME', True),
            'additional_tag_file': d.getVar('INCLUDE_CROSS_REFERENCE_ADDITIONAL_TAG_FILE', True)
        }
    }
    param['cross_reference']['rel_path_to_tag'] = os.path.join(param['package_name'], "include", param['cross_reference']['tag_name'])
    bb.plain("Generate cross-reference for headers")
    cross_reference_task(d, param)
}
addtask do_include_cross_reference after do_all_cross_reference

SSTATETASKS += "do_merge_all_cross_reference"
do_merge_all_cross_reference[sstate-inputdirs] = "${CROSS_REFERENCE_MERGE_DIR}"
do_merge_all_cross_reference[sstate-outputdirs] = "${CROSS_REFERENCE_SSTATE_CACHES_DIR}"

python do_merge_all_cross_reference_setscene () {
    sstate_setscene(d)
}

addtask do_merge_all_cross_reference_setscene

SSTATETASKS += "do_include_cross_reference"
CROSS_REFERENCE_SSTATE_CACHES_INCLUDE_DIR = "${CROSS_REFERENCE_SSTATE_CACHES_PACKAGE_DIR}/include"

do_include_cross_reference[sstate-inputdirs] = "${INCLUDE_CROSS_REFERENCE_TAG_DIR}"
do_include_cross_reference[sstate-outputdirs] = "${CROSS_REFERENCE_SSTATE_CACHES_INCLUDE_DIR}"

python do_include_cross_reference_setscene () {
    sstate_setscene(d)
}

addtask do_include_cross_reference_setscene