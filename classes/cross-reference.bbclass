# Copyright (C) 2017 Inango Systems Ltd
# Released under the ******  license (see COPYING.INANGO for the terms)

DESCRIPTION = "Creates and merges tags files for all build packages"

CROSS_REFERENCE_TOOL ?= "ctags"
CROSS_REFERENCE_ERROR_ON_FAILURE ?= "info"

CROSS_REFERENCE_TAG_NAME = "recipe.tags"
CROSS_REFERENCE_TAG_DIR = "${WORKDIR}/cross-reference"
CROSS_REFERENCE_TAG_FILE_PATH ?= "${CROSS_REFERENCE_TAG_DIR}/${CROSS_REFERENCE_TAG_NAME}"
CROSS_REFERENCE_ADDITIONAL_TAG_FILE = "additional_tag_file"
CROSS_REFERENCE_CMD_ctags = "ctags --file-scope=no --recurse -f ${CROSS_REFERENCE_TAG_FILE_PATH} `pwd`"
CROSS_REFERENCE_CMD_cscope = "cscope -Rb -f ${CROSS_REFERENCE_TAG_FILE_PATH}"

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

    def error_on_failure(message):
        if d.getVar('CROSS_REFERENCE_ERROR_ON_FAILURE', True) == "error":
            bb.fatal(message + d.getVar('PN', True))
        elif d.getVar('CROSS_REFERENCE_ERROR_ON_FAILURE', True) == "warning":
            bb.warn(message+ d.getVar('PN', True))
        else:
            bb.plain(message + d.getVar('PN', True))

    current_dir = os.getcwd()
    try:
        os.chdir(d.getVar('S',True))
    except FileNotFoundError:
        bb.plain("Can't create tags file for package: " + d.getVar('PN', True))
        return

    if d.getVar('CROSS_REFERENCE_CMD_' + d.getVar('CROSS_REFERENCE_TOOL', True), True) is None:
        # add command as a variable to create tag file
        bb.fatal("Command for creating tag file with " + d.getVar('CROSS_REFERENCE_TOOL', True) + " utility is not specified")

    if not os.path.exists(d.getVar('CROSS_REFERENCE_TAG_DIR', True)):
        os.mkdir(d.getVar('CROSS_REFERENCE_TAG_DIR', True))

    retvalue = os.system(d.getVar("CROSS_REFERENCE_CMD_" + d.getVar('CROSS_REFERENCE_TOOL', True), True))

    if retvalue != 0:
        error_on_failure("Can't create tags file for package: ")
    else:
        if not os.path.exists(d.getVar('CROSS_REFERENCE_TAG_FILE_PATH', True)):
            error_on_failure("Tag file was not created: ")
        else:
            execute_command = 'echo %s - %s > %s' % (d.getVar('PN', True), os.path.join(d.getVar('PN', True), d.getVar('CROSS_REFERENCE_TAG_NAME', True)), d.getVar('CROSS_REFERENCE_ADDITIONAL_TAG_FILE', True))
            os.system(execute_command)
            bb.note("Tag file was created. See directory: " + d.getVar('B',True) + " for details")

    os.chdir(current_dir)
}

addtask cross_reference after do_patch before do_build

SSTATETASKS += "do_cross_reference"
CROSS_REFERENCE_SSTATE_CACHES_DIR = "${STAGING_DIR}/${MACHINE}/cross-reference"
CROSS_REFERENCE_SSTATE_CACHES_PACKAGE_DIR = "${CROSS_REFERENCE_SSTATE_CACHES_DIR}/${PN}"

do_cross_reference[sstate-inputdirs] = "${CROSS_REFERENCE_TAG_DIR}"
do_cross_reference[sstate-outputdirs] = "${CROSS_REFERENCE_SSTATE_CACHES_PACKAGE_DIR}"

python do_cross_reference_setscene () {
    sstate_setscene(d)
}

addtask do_cross_reference_setscene