# Copyright (C) 2017 Inango Systems Ltd
# Released under the ******  license (see COPYING.INANGO for the terms)

inherit image_types

DESCRIPTION = "Merges tags files for all build packages"

CROSS_REFERENCE_ALLTAGS_FILENAME ?= "${TOPDIR}/all_tags"
CROSS_REFERENCE_MERGE_CMD_ctags = "cd ${TMPDIR} && find work* -type f -name ${CROSS_REFERENCE_TAG_FILE_PATH} -exec cat \{} \; | sort -u > ${CROSS_REFERENCE_ALLTAGS_FILENAME}"

CROSS_REFERENCE_DIR ?= "${STAGING_DIR}/${MACHINE}/cross-reference"
CROSS_REFERENCE_LIST_OF_TAGS ?= "${CROSS_REFERENCE_DIR}/list_of_tags"

do_merge_all_cross_reference[doc] = "Merges multiple tag files"

python do_merge_all_cross_reference() {
    if d.getVar('CROSS_REFERENCE_MERGE_CMD_' + d.getVar('CROSS_REFERENCE_TOOL', True), True) is None:
        bb.fatal("Command for merge tags file with " + d.getVar('CROSS_REFERENCE_TOOL', True) + " utility is not specified")

    retvalue = os.system(d.getVar("CROSS_REFERENCE_MERGE_CMD_" + d.getVar('CROSS_REFERENCE_TOOL', True), True))

    if retvalue != 0:
        if d.getVar('CROSS_REFERENCE_ERROR_ON_FAILURE', True) == "error":
            bb.fatal("Can't merge tags file for image: " + d.getVar('PN', True))
        elif d.getVar('CROSS_REFERENCE_ERROR_ON_FAILURE', True) == "warning":
            bb.warn("Can't merge tags file for image: " + d.getVar('PN', True))
        else:
            bb.plain("Can't merge tags file for image: " + d.getVar('PN', True))
    else:
        if not os.path.exists(d.getVar('CROSS_REFERENCE_DIR', True)):
            os.mkdir(d.getVar('CROSS_REFERENCE_DIR', True))
        execute_command = 'find %s -name %s -type f | xargs cat > %s' % (d.getVar('TOPDIR', True), d.getVar('CROSS_REFERENCE_ADDITIONAL_TAG_FILE', True), d.getVar('CROSS_REFERENCE_LIST_OF_TAGS', True))
        os.system(execute_command)
        bb.note("Merges tag files was succsesfull for image: " + d.getVar('PN', True))

}

addtask merge_all_cross_reference after do_all_cross_reference before do_build