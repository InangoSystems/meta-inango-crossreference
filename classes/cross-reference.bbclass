#
# Copyright 2019, Inango Systems Ltd.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


DESCRIPTION = "Creates tags files for all built packages"

CROSS_REFERENCE_ERROR_ON_FAILURE ?= "info"

# Default cross reference tool is "ctags", so default values of related variables should be relevant for "ctags"
CROSS_REFERENCE_TOOL ?= "ctags"

CROSS_REFERENCE_TAG_NAME_ctags ?= "tags"
CROSS_REFERENCE_TAG_NAME_cscope ?= "cscope.out"
CROSS_REFERENCE_TAG_NAME ?= "${@d.getVar('CROSS_REFERENCE_TAG_NAME_' + d.getVar('CROSS_REFERENCE_TOOL', True), True)}"

CROSS_REFERENCE_CMD_ctags ?= "ctags --file-scope=no --recurse -f ${CROSS_REFERENCE_TAG_FILE_PATH} `pwd`"
CROSS_REFERENCE_CMD_cscope ?= 'cscope -R -b -f "${CROSS_REFERENCE_TAG_FILE_PATH}"'

CROSS_REFERENCE_TAG_DIR ?= "${WORKDIR}/cross-reference"
CROSS_REFERENCE_TAG_FILE_PATH ?= "${CROSS_REFERENCE_TAG_DIR}/${CROSS_REFERENCE_TAG_NAME}"

CROSS_REFERENCE_ADDITIONAL_TAG_FILE ?= "source.atf"
CROSS_REFERENCE_ADDITIONAL_TAG_PATH ?= "${S}/${CROSS_REFERENCE_ADDITIONAL_TAG_FILE}"

CROSS_REFERENCE_FAIL_REASON_FILE_NAME ?= "fail.frf"
CROSS_REFERENCE_FAIL_REASON_FILE_PATH ?= "${S}/${CROSS_REFERENCE_FAIL_REASON_FILE_NAME}"
CROSS_REFERNCE_LOG_FILE_PATH ?= ""
CROSS_REFERENCE_PREV_STATE_FILE ?= ""

CROSS_REFERENCE_ENABLE_FOR_NATIVE[doc] = "Turn on cross-reference for native recipes. If equal '1' then enabled, if '0' - disabled (default)"
CROSS_REFERENCE_ENABLE_FOR_NATIVE ?= '0'

CROSS_REFERENCE_ENABLE_FOR_KERNEL[doc] = "Turn on cross-reference for kernel. If equal '1' then enabled, if '0' - disabled (default)"
CROSS_REFERENCE_ENABLE_FOR_KERNEL ?= '0'
CROSS_REFERENCE_KERNEL ?= "${PREFERRED_PROVIDER_virtual/kernel}"

CROSS_REFERENCE_IGNORED_RECIPES[doc] = "Turn off cross-reference for recipes which names are matched by regexp. \
To disable some of regexp use '_remove' notation, for example, CROSS_REFERENCE_IGNORED_RECIPES_remove = 'libgcc.*' \
"
CROSS_REFERENCE_IGNORED_RECIPES += "gcc-.* \
   libgcc.* \
   linux-libc-headers \
"

do_all_cross_reference[doc] = "Creates tag file of language objects found in source files for active packages recursively"
addtask do_all_cross_reference after do_cross_reference
do_all_cross_reference[recrdeptask] = "do_all_cross_reference do_cross_reference"
do_all_cross_reference[recideptask] = "do_${BB_DEFAULT_TASK}"
do_all_cross_reference() {
    :
}

do_cross_reference[doc] = "Creates tag file of language objects found in source files"
do_cross_reference[depends] = "${CROSS_REFERENCE_TOOL}-native:do_populate_sysroot"
do_cross_reference[dirs] = "${CROSS_REFERENCE_TAG_DIR}"

def cross_reference_fail(file_path, recipe_name, fail_type = "fail"):
    text = "%s\t\t%s\n" % (recipe_name, fail_type)
    with open(file_path, 'w') as fo:
        fo.write(text)

def analyze_indexer_log(path_to_log, prev_state_file):
    return 0, ""

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
            'additional_tag_path': d.getVar('CROSS_REFERENCE_ADDITIONAL_TAG_PATH', True) # It is additional file and need for merge_all_cross_referense_task.
                                                                                         # This file have next format: ${PN} - ${PN}/${CROSS_REFERENCE_TAG_NAME}.
        }
    """

    current_dir = os.getcwd()
    try:
        os.chdir(param['source'])
    except FileNotFoundError:
        bb.plain("Can't create tags file for target: {}".format(param['package_name']))
        return

    if param['cross_reference']['command'] is None:
        # add command as a variable to create tag file
        bb.fatal('Command for creating tag file with "{}" utility is not specified'.format(param['cross_reference']['tool']))

    bb.note("CWD: " + os.getcwd())
    bb.note(param['cross_reference']['command'])
    retvalue = os.system(param['cross_reference']['command'])
    fail = False
    if retvalue != 0:
        fail = True
        fail_type = "can't_create_tag"
        error_on_failure(d, "Can't create tags file for target: {}".format(param['package_name']))
    else:
        if not os.path.exists(param['cross_reference']['tag_file_path']):
            fail = True
            fail_type = "tag_was_not_created"
            error_on_failure(d, 'Tag file was not created for target: {}'.format(param['package_name']))
        else:
            analyze_res = analyze_indexer_log(d.getVar('CROSS_REFERNCE_LOG_FILE_PATH', True), d.getVar('CROSS_REFERENCE_PREV_STATE_FILE', True))
            bb.plain( d.getVar('CROSS_REFERENCE_PREV_STATE_FILE', True))
            if analyze_res[0] != 0:
                fail = True
                fail_type = analyze_res[1]
            cmd = 'echo {} - {} > {}'.format(param['package_name'], param['cross_reference']['rel_path_to_tag'], param['cross_reference']['additional_tag_path'])
            bb.note("CWD: " + os.getcwd())
            bb.note(cmd)
            os.system(cmd)
            bb.note("Tag file was created. See directory: %s for details" % param['cross_reference']['tag_dir'])
    os.chdir(current_dir)
    if fail:
        cross_reference_fail(d.getVar('CROSS_REFERENCE_FAIL_REASON_FILE_PATH', True), param['package_name'], fail_type)


def error_on_failure(d, message):
    if d.getVar('CROSS_REFERENCE_ERROR_ON_FAILURE', True) == "error":
        bb.fatal(message)
    elif d.getVar('CROSS_REFERENCE_ERROR_ON_FAILURE', True) == "warning":
        bb.warn(message)
    else:
        bb.plain(message)

def default_cross_reference(d):
    """
    This function execute cross_reference_task with parameters for the source.
    """
    import re
    pn = d.getVar('PN', True)
    if re.compile(re.sub("\s+", "|", d.getVar('CROSS_REFERENCE_IGNORED_RECIPES', True).strip())).match(pn) :
        cross_reference_fail(d.getVar('CROSS_REFERENCE_FAIL_REASON_FILE_PATH',True), pn, 'ignore')
        bb.plain("The recipe \"{}\" is ignored for cross-reference".format(pn))
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
            'additional_tag_path': d.getVar('CROSS_REFERENCE_ADDITIONAL_TAG_PATH', True)
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
        cross_reference_fail(d.getVar('CROSS_REFERENCE_FAIL_REASON_FILE_PATH',True), pn, 'ignore')
        bb.plain("The native recipe %s is ignored for cross-reference" % pn)

}

do_cross_reference_pn-${CROSS_REFERENCE_KERNEL}() {
    if d.getVar('CROSS_REFERENCE_ENABLE_FOR_KERNEL', True) == '1':
        default_cross_reference(d)
    else:
        pn = d.getVar('PN', True)
        cross_reference_fail(d.getVar('CROSS_REFERENCE_FAIL_REASON_FILE_PATH',True), pn, 'ignore')
        bb.plain("The kernel recipe %s is ignored for cross-reference" % pn)
}

addtask do_cross_reference after do_configure before do_build
#
# sstate cache support
#
SSTATETASKS += "do_cross_reference"
# Not use ${STAGING_DIR_HOST} instead of ${STAGING_DIR}/${MACHINE}, because for case of
# native packages the value of STAGING_DIR_HOST is empty
CROSS_REFERENCE_SSTATE_CACHES_DIR ?= "${STAGING_DIR}/${MACHINE}/cross-reference"
CROSS_REFERENCE_SSTATE_CACHES_PACKAGE_DIR ?= "${CROSS_REFERENCE_SSTATE_CACHES_DIR}/${PN}"

do_cross_reference[sstate-inputdirs] = "${CROSS_REFERENCE_TAG_DIR}"
do_cross_reference[sstate-outputdirs] = "${CROSS_REFERENCE_SSTATE_CACHES_PACKAGE_DIR}"

python do_cross_reference_setscene () {
    sstate_setscene(d)
}

addtask do_cross_reference_setscene

do_cross_reference[vardepsexclude] += "S B D CROSS_REFERENCE_TAG_DIR CROSS_REFERENCE_ADDITIONAL_TAG_PATH CROSS_REFERENCE_FAIL_REASON_FILE_PATH CROSS_REFERENCE_FAIL_REASON_FILE_PATH CROSS_REFERNCE_LOG_FILE_PATH CROSS_REFERENCE_PREV_STATE_FILE CROSS_REFERENCE_ENABLE_FOR_NATIVE CROSS_REFERENCE_ENABLE_FOR_KERNEL CROSS_REFERENCE_KERNEL CROSS_REFERENCE_IGNORED_RECIPES STAMPS_DIR"
#
# Support relative paths in cross reference files stored in sstate caches
#
SSTATE_SCAN_FILES += "${CROSS_REFERENCE_TAG_NAME}"
EXTRA_STAGING_FIXMES += "WORKDIR STAGING_DIR_HOST STAGING_DIR_TARGET"

# workaround for Yocto 2.2 (morty)
SSTATECREATEFUNCS_append = " sstate_hardcode_path_cr"

python sstate_hardcode_path_cr () {
    import subprocess
    import platform
    import os.path
    import os

    sstate_builddir = d.getVar("SSTATE_BUILDDIR", True)
    fixmefn = os.path.join(sstate_builddir, "fixmepath")

    sstate_filelist_cmd = "tee -a %s" % (fixmefn)

    sstate_sed_cmd = "sed -i"

    extra_staging_fixmes = d.getVar('EXTRA_STAGING_FIXMES', True) or ''
    for fixmevar in extra_staging_fixmes.split():
        fixme_path = d.getVar(fixmevar, True)
        sstate_sed_cmd += " -e 's:%s:FIXME_%s:g'" % (fixme_path, fixmevar)

    xargs_no_empty_run_cmd = '--no-run-if-empty'
    if platform.system() == 'Darwin':
        xargs_no_empty_run_cmd = ''

    sstate_hardcode_cmd = "find %s -name %s -type f | %s | xargs %s %s" % (
        sstate_builddir,
        d.getVar("CROSS_REFERENCE_TAG_NAME", True),
        sstate_filelist_cmd,
        xargs_no_empty_run_cmd,
        sstate_sed_cmd)

    # bb.note("Removing hardcoded paths from sstate package by cmd: '%s'" % (sstate_hardcode_cmd))
    subprocess.call(sstate_hardcode_cmd, shell=True)

    # fixmepath file needs relative paths, drop sstate_builddir prefix
    sstate_filelist_relative_cmd = "sed -i -e 's:^%s::g' %s" % (sstate_builddir, fixmefn)

    # If the fixmefn is empty, remove it..
    if os.stat(fixmefn).st_size == 0:
        os.remove(fixmefn)
    else:
        # bb.note("Make paths in fixmepath file relative by cmd: '%s'" % (sstate_filelist_relative_cmd))
        subprocess.call(sstate_filelist_relative_cmd, shell=True)
}
