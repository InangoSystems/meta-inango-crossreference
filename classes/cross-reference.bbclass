# Copyright (C) 2017 Inango Systems Ltd
# Released under the ******  license (see COPYING.INANGO for the terms)

DESCRIPTION = "Creates and merges tags files for all build packages"

CROSS_REFERENCE_TOOL ?= "ctags"
CROSS_REFERENCE_ERROR_ON_FAILURE ?= "info"

CROSS_REFERENCE_CMD_ctags = "ctags --file-scope=no --recurse `pwd`"
CROSS_REFERENCE_CMD_cscope = "cscope -Rb"


ROOTFS_POSTPROCESS_COMMAND_append = " do_merge_all_cross_reference; "
ALLTAGS_FILENAME ?= "${TOPDIR}/tags"

do_merge_all_cross_reference[doc] = "Merges multiple tag files"
do_merge_all_cross_reference[deptask] = "do_all_cross_reference"

do_merge_all_cross_reference() {
    if [ "${CROSS_REFERENCE_TOOL}" = "ctags" ]; then
        cd ${TMPDIR}
        find work* -type f -name tags -exec cat \{} \; | sort -u > ${ALLTAGS_FILENAME}
    else
        #add your own behaviour to merge files are created by the certain tags tool
        bbfatal "do_merge_all_cross_reference() task does not support for ${CROSS_REFERENCE_TOOL} utility"
    fi

}



do_all_cross_reference[doc] = "Creates tag file of language objects found in source files for all packages"

addtask do_all_cross_reference after do_cross_reference
do_all_cross_reference[recrdeptask] = "do_all_cross_reference do_cross_reference"
do_all_cross_reference[recideptask] = "do_${BB_DEFAULT_TASK}"
do_all_cross_reference() {
    :
}

do_cross_reference[doc] = "Creates tag file of language objects found in source files"
do_cross_reference[depends] = "${CROSS_REFERENCE_TOOL}-native:do_populate_sysroot"

python do_cross_reference () {
    current_dir = os.getcwd()

    try:
        os.chdir(d.getVar('S',True))
    except FileNotFoundError:
        bb.plain("Can't create tags file for package: " + d.getVar('PN', True))
        return

    if d.getVar('CROSS_REFERENCE_CMD_' + d.getVar('CROSS_REFERENCE_TOOL', True), True) is None:
        # add command as a variable to create tag file
        bb.fatal("Command for creating tag file with " + d.getVar('CROSS_REFERENCE_TOOL', True) + " utility is not specified")

    retvalue = os.system(d.getVar("CROSS_REFERENCE_CMD_" + d.getVar('CROSS_REFERENCE_TOOL', True), True))

    if retvalue != 0:
        if d.getVar('CROSS_REFERENCE_ERROR_ON_FAILURE', True) == "error":
            bb.fatal("Can't create tags file for package: " + d.getVar('PN', True))
        elif d.getVar('CROSS_REFERENCE_ERROR_ON_FAILURE', True) == "warning":
            bb.warn("Can't create tags file for package: " + d.getVar('PN', True))
        else:
            bb.plain("Can't create tags file for package: " + d.getVar('PN', True))
    else:
        bb.note("Tag file was created. See directory: " + d.getVar('S',True) + " for details")

    os.chdir(current_dir)
}

addtask cross_reference after do_patch before do_build
