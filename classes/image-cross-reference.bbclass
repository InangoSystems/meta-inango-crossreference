# Copyright (C) 2019 Inango Systems Ltd
# Released under the ******  license (see COPYING.INANGO for the terms)

inherit image_types
inherit cross-reference

DESCRIPTION = "Merges cross reference tags files for all built packages"

CROSS_REFERENCE_MERGE_DIR ?= "${WORKDIR}/merge-cross-reference"
CROSS_REFERENCE_MERGE_DIR[doc] = "Used as input dir for sstate cache.\n\
                                  Should contains only cumulative tags file. "

CROSS_REFERENCE_ALLTAGS_FILENAME ?= "tags"
CROSS_REFERENCE_ALLTAGS_DIR ?= "${TOPDIR}"

CROSS_REFERENCE_MERGE_CMD[doc] = "Do not use this variable directly. \
    Use CROSS_REFERENCE_MERGE_CMD_${CROSS_REFERENCE_TOOL} instead, i.e. CROSS_REFERENCE_MERGE_CMD_ctags. \
    \
    This command must generate cumulative crossref index with path '${CROSS_REFERENCE_ALLTAGS_DIR}/${CROSS_REFERENCE_ALLTAGS_FILENAME}' "

# That is a problem with filtering tags by strict names or extensions, because name of tag file maybe redefined in each recipe, so we miss it
CROSS_REFERENCE_MERGE_CMD_ctags ?= 'find "${CROSS_REFERENCE_SSTATE_CACHES_DIR}" -type f | xargs sort -u > ${CROSS_REFERENCE_ALLTAGS_DIR}/${CROSS_REFERENCE_ALLTAGS_FILENAME}'

CROSS_REFERENCE_LIST_OF_TAGS_NAME ?= "list_of_tags"
CROSS_REFERENCE_LIST_OF_TAGS_PATH ?= "${CROSS_REFERENCE_MERGE_DIR}/${CROSS_REFERENCE_LIST_OF_TAGS_NAME}"

CROSS_REFERENCE_FAILS_LIST_NAME ?= "cross-reference_fail_list"
CROSS_REFERENCE_FAILS_LIST_PATH ?= "${CROSS_REFERENCE_MERGE_DIR}/${CROSS_REFERENCE_FAILS_LIST_NAME}"

do_merge_all_cross_reference[doc] = "Merges multiple cross reference files"
do_merge_all_cross_reference[dirs] = "${CROSS_REFERENCE_MERGE_DIR}"

python do_merge_all_cross_reference() {
    import shutil

    pn = d.getVar('PN', True)

    if d.getVar("CROSS_REFERENCE_MERGE_CMD_" + d.getVar("CROSS_REFERENCE_TOOL", True), True) is None:
        bb.fatal('Command for merge tags file with "{}"" utility is not specified'.format(d.getVar("CROSS_REFERENCE_TOOL", True)))

    alltags_path = os.path.join(d.getVar("CROSS_REFERENCE_ALLTAGS_DIR", True), d.getVar("CROSS_REFERENCE_ALLTAGS_FILENAME", True))
    if os.path.islink(alltags_path):
        os.remove(alltags_path)

    st = os.system(d.getVar("CROSS_REFERENCE_MERGE_CMD_" + d.getVar("CROSS_REFERENCE_TOOL", True), True))
    if st != 0:
        error_on_failure(d, "Can't merge tags file for image: {}".format(pn))
    else:
        bb.note('{}: cross reference files were successfully merged into "{}"'.format(pn, alltags_path))
        #
        # Result of merge maybe situated in any place, because var CROSS_REFERENCE_ALLTAGS_PATH maybe redefined outside
        # So we should explicitly copy it into directory, which will be used as sstate input directory
        if not os.path.isfile(alltags_path):
            error_on_failure(d, 'Merged cross reference file for image "{}" not found: {}'.format(pn, alltags_path))
        else:
            alltags_in_merge_dir = os.path.join(d.getVar("CROSS_REFERENCE_MERGE_DIR", True), d.getVar("CROSS_REFERENCE_ALLTAGS_FILENAME", True))
            if alltags_in_merge_dir != alltags_path:
                shutil.move(alltags_path, alltags_in_merge_dir)
                os.symlink(alltags_in_merge_dir, alltags_path)  # alltags_path -> alltags_in_merge_dir

            st, msg = merge_cross_reference_additional_files(d)
            if st != 0:
                bb.warn(errmsg)
            else:
                bb.note(msg)

    st, msg = merge_do_cross_reference_fail_logs(d)
    if st != 0:
        bb.warn(errmsg)
    else:
        bb.note(msg)
}

def merge_cross_reference_additional_files(d):
    ltpath = d.getVar('CROSS_REFERENCE_LIST_OF_TAGS_PATH', True)
    execute_command = 'find -L "{}" -name "{}" -type f | xargs cat > "{}"'.format(
            d.getVar('TMPDIR', True), 
            "*.atf",  # FIXME: extension must be got from atf file name saved in variable 
            ltpath)
    st = os.system(execute_command)
    if st != 0:
        return st, 'Could not merge cross reference additional files into "{}"'.format(ltpath)
    else:
        return st, 'Cross reference additional files were merged successfully: {}'.format(ltpath)


def merge_do_cross_reference_fail_logs(d):
    flpath = d.getVar('CROSS_REFERENCE_FAILS_LIST_PATH', True)

    execute_command = 'find -L "{}" -name "{}" -type f | xargs cat > "{}"'.format(
        d.getVar('TMPDIR', True), d.getVar('CROSS_REFERENCE_FAIL_REASON_FILE_NAME',True), flpath)
    st = os.system(execute_command)
    if st != 0:
        return st, 'Could not merge cross reference fail logs into "{}"'.format(d.getVar(flpath))
    else:
        return st, 'Cross reference fail logs merged successfully: {}'.format(flpath)


addtask merge_all_cross_reference after do_all_cross_reference before do_build
#
# sstate cache is not working for "merge_all_cross_reference"
# if add sstate cache support and delete 'TMPDIR', then real "merge_all_cross_reference" task
# will be run instead of using sstate cache content
