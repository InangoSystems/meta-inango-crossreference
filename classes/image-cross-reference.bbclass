# Copyright (C) 2019 Inango Systems Ltd
# Released under the ******  license (see COPYING.INANGO for the terms)

inherit image_types
inherit cross-reference

DESCRIPTION = "Merges cross reference tags files for all built packages"

CROSS_REFERENCE_MERGE_DIR ?= "${WORKDIR}/merge-cross-reference"
CROSS_REFERENCE_ALLTAGS_FILENAME ?= "tags"
CROSS_REFERENCE_ALLTAGS_PATH ?= "${CROSS_REFERENCE_MERGE_DIR}/${CROSS_REFERENCE_ALLTAGS_FILENAME}"
CROSS_REFERENCE_MERGE_CMD_ctags ?= "find ${CROSS_REFERENCE_SSTATE_CACHES_DIR} -type f -name '*.tag' -exec cat \{} \; | sort -u > ${CROSS_REFERENCE_ALLTAGS_PATH}"

CROSS_REFERENCE_LIST_OF_TAGS_NAME ?= "list_of_tags"
CROSS_REFERENCE_FAILS_LIST_NAME ?= "cross-reference_fail_list"
CROSS_REFERENCE_LIST_OF_TAGS_PATH ?= "${CROSS_REFERENCE_MERGE_DIR}/${CROSS_REFERENCE_LIST_OF_TAGS_NAME}"
CROSS_REFERENCE_FAILS_LIST_PATH ?= "${CROSS_REFERENCE_MERGE_DIR}/${CROSS_REFERENCE_FAILS_LIST_NAME}"

do_merge_all_cross_reference[doc] = "Merges multiple tag files"

python do_merge_all_cross_reference() {
    if d.getVar('CROSS_REFERENCE_MERGE_CMD_' + d.getVar('CROSS_REFERENCE_TOOL', True), True) is None:
        bb.fatal("Command for merge tags file with " + d.getVar('CROSS_REFERENCE_TOOL', True) + " utility is not specified")

    if not os.path.exists(d.getVar('CROSS_REFERENCE_MERGE_DIR', True)):
        os.mkdir(d.getVar('CROSS_REFERENCE_MERGE_DIR', True))
    retvalue = os.system(d.getVar("CROSS_REFERENCE_MERGE_CMD_" + d.getVar('CROSS_REFERENCE_TOOL', True), True))

    if retvalue != 0:
        error_on_failure(d, "Can't merge tags file for image: " + d.getVar('PN', True))
    else:
        execute_command = 'find %s -name %s -type f | xargs cat > %s' % (d.getVar('TMPDIR', True), "*.atf", d.getVar('CROSS_REFERENCE_LIST_OF_TAGS_PATH', True))
        os.system(execute_command)
        bb.note("Merges tag files was succsesfull for image: " + d.getVar('PN', True))
    execute_command = 'find %s -name %s -type f | xargs cat > %s' % (d.getVar('TMPDIR', True), d.getVar('CROSS_REFERENCE_FAIL_REASON_FILE_NAME',True), d.getVar('CROSS_REFERENCE_FAILS_LIST_PATH', True))
    os.system(execute_command)

}

addtask merge_all_cross_reference after do_all_cross_reference before do_build

SSTATETASKS += "do_merge_all_cross_reference"
do_merge_all_cross_reference[sstate-inputdirs] = "${CROSS_REFERENCE_MERGE_DIR}"
do_merge_all_cross_reference[sstate-outputdirs] = "${CROSS_REFERENCE_SSTATE_CACHES_DIR}"

python do_merge_all_cross_reference_setscene () {
    sstate_setscene(d)
}

addtask do_merge_all_cross_reference_setscene
