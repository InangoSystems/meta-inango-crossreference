# Copyright (C) 2017 Inango Systems Ltd
# Released under the ******  license (see COPYING.INANGO for the terms)

DESCRIPTION = "Creates and merges tags files for all build packages"

CROSS_REFERENCE_TOOL ?= "ctags"
CROSS_REFERENCE_ERROR_ON_FAILURE ?= "info"

CROSS_REFERENCE_TAG_NAME = "source.tag"
CROSS_REFERENCE_TAG_DIR = "${WORKDIR}/cross-reference"
CROSS_REFERENCE_TAG_FILE_PATH ?= "${CROSS_REFERENCE_TAG_DIR}/${CROSS_REFERENCE_TAG_NAME}"
CROSS_REFERENCE_ADDITIONAL_TAG_FILE = "source.atf"
CROSS_REFERENCE_CMD_ctags = "ctags --file-scope=no --recurse -f ${CROSS_REFERENCE_TAG_FILE_PATH} `pwd`"
CROSS_REFERENCE_CMD_cscope = "cscope -Rb -f ${CROSS_REFERENCE_TAG_FILE_PATH}"

CROSS_REFERENCE_KERNEL = "${PREFERRED_PROVIDER_virtual/kernel}"
#For enabled cross-reference for native/kernel
#set ${CROSS_REFERENCE_ENABLE_FOR_NATIVE}/${CROSS_REFERENCE_ENABLE_FOR_KERNEL} to '1'
#For disabled set to '0' (default)
CROSS_REFERENCE_ENABLE_FOR_NATIVE ?= '0'
CROSS_REFERENCE_ENABLE_FOR_KERNEL ?= '0'
CROSS_REFERENCE_IGNORED_RECIPES += "gcc-.* \
   libgcc.* \
   linux-libc-headers \
   linux-intel-headers \
"

do_all_cross_reference[doc] = "Creates tag file of language objects found in source files for all packages"

addtask do_all_cross_reference after do_cross_reference
do_all_cross_reference[recrdeptask] = "do_all_cross_reference do_cross_reference"
do_all_cross_reference[recideptask] = "do_${BB_DEFAULT_TASK}"
do_all_cross_reference() {
    :
}

do_cross_reference[doc] = "Creates tag file of language objects found in source files"
do_cross_reference[depends] = "${CROSS_REFERENCE_TOOL}-native:do_populate_sysroot"
do_cross_reference[dirs] = "${CROSS_REFERENCE_TAG_DIR}"

def cross_reference_task(d, param):
    """
    cross-reference task given dictionary "param" which must have next structure:
    param = {
        'package_name': d.getVar('PN', True), # Package name
        'source': d.getVar('S',True), # Source dir
        'cross_reference':{ # Cross reference parameters
            'tool': d.getVar('CROSS_REFERENCE_TOOL', True), # Cross reference tool. For example eclipse, ctags, cscope
            'command': d.getVar("CROSS_REFERENCE_CMD_" + d.getVar('CROSS_REFERENCE_TOOL', True), True), # Cross reference tool
            'tag_dir': d.getVar('CROSS_REFERENCE_TAG_DIR', True), # A directory where tags will be generated
            'tag_file_path': d.getVar('CROSS_REFERENCE_TAG_FILE_PATH', True), # Path to tag file
            'tag_name': d.getVar('CROSS_REFERENCE_TAG_NAME', True), # Name of tag file
            'additional_tag_file': d.getVar('CROSS_REFERENCE_ADDITIONAL_TAG_FILE', True) # It is additional file and need for merge_all_cross_referense_task.
                                                                                         # This file have next format: ${PN} - ${PN}/${CROSS_REFERENCE_TAG_NAME}. 
        }
    """
    def error_on_failure(d, message):
        if d.getVar('CROSS_REFERENCE_ERROR_ON_FAILURE', True) == "error":
            bb.fatal(message)
        elif d.getVar('CROSS_REFERENCE_ERROR_ON_FAILURE', True) == "warning":
            bb.warn(message)
        else:
            bb.plain(message)

    current_dir = os.getcwd()
    try:
        os.chdir(param['source'])
    except FileNotFoundError:
        bb.plain("Can't create tags file for target: %s" % param['package_name'])
        return

    if param['cross_reference']['command'] is None:
        # add command as a variable to create tag file
        bb.fatal("Command for creating tag file with %s utility is not specified" % param['cross_reference']['tool'])
    
    retvalue = os.system(param['cross_reference']['command'])

    if retvalue != 0:
        error_on_failure(d, "Can't create tags file for target: %s" % param['package_name'])
    else:
        if not os.path.exists(param['cross_reference']['tag_file_path']):
            error_on_failure(d, "Tag file was not created for target: %s" % param['package_name'])
        else:
            execute_command = 'echo %s - %s > %s' % (param['package_name'], param['cross_reference']['rel_path_to_tag'], param['cross_reference']['additional_tag_file'])
            os.system(execute_command)
            bb.note("Tag file was created. See directory: %s for details" % param['cross_reference']['tag_dir'])
    os.chdir(current_dir)

def default_cross_reference(d):
    """
    This function execute cross_reference_task with parameters for the source.
    """
    import re
    pn = d.getVar('PN', True)
    if re.compile(re.sub("\s+", "|", d.getVar('CROSS_REFERENCE_IGNORED_RECIPES', True).strip())).match(pn) :
        bb.plain("The recipe %s is ignored for cross-reference" % pn)
        return
    param = {
        'package_name': pn,
        'source': d.getVar('S',True),
        'cross_reference':{
            'tool': d.getVar('CROSS_REFERENCE_TOOL', True),
            'command': d.getVar("CROSS_REFERENCE_CMD_" + d.getVar('CROSS_REFERENCE_TOOL', True), True),
            'tag_dir': d.getVar('CROSS_REFERENCE_TAG_DIR', True),
            'tag_file_path': d.getVar('CROSS_REFERENCE_TAG_FILE_PATH', True),
            'tag_name': d.getVar('CROSS_REFERENCE_TAG_NAME', True),
            'additional_tag_file': d.getVar('CROSS_REFERENCE_ADDITIONAL_TAG_FILE', True)
        }
    }
    param['cross_reference']['rel_path_to_tag'] = os.path.join(param['package_name'], param['cross_reference']['tag_name'])
    cross_reference_task(d, param)

python do_cross_reference () {
   default_cross_reference(d)
}

python do_cross_reference_class-native(){
    if d.getVar('CROSS_REFERENCE_ENABLE_FOR_NATIVE', True) == '1':
        default_cross_reference(d)
    else:
        pn = d.getVar('PN', True)
        bb.plain("The recipe %s is ignored for cross-reference" % pn)

}

do_cross_reference_pn-${CROSS_REFERENCE_KERNEL}() {
    if d.getVar('CROSS_REFERENCE_ENABLE_FOR_KERNEL', True) == '1':
        default_cross_reference(d)
    else:
        pn = d.getVar('PN', True)
        bb.plain("The recipe %s is ignored for cross-reference" % pn)
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
